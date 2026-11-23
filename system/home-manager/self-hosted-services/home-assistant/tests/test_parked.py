"""Parked vehicles that Frigate found again, from the live alerts that started this."""

from __future__ import annotations

import asyncio

import pytest

from core.burst import BurstWindow
from core.decide import decide
from core.parked import (
    MEMORY_SECONDS,
    RECENT_SECONDS,
    VEHICLES,
    Sighting,
    ended_here,
    in_parking_zones,
    in_zone,
    iou,
    is_parked,
    on_spots,
    parked_spot,
    parking_zones,
    path_points,
    same_place,
    seen_for_a_while,
    sightings,
    still,
)
from core.policy import CRITICAL, REVIEW_ONLY
from core.pushes import PushBudget
from core.quiet import PAUSE, QuietEntry

# The bike parked on the veranda from 17:26 to 20:06 (event 1794830193.963433-plqzpq),
# trimmed to its first and last path points.
PARKED_BIKE = {
    "id": "1794830193.963433-plqzpq",
    "label": "motorcycle",
    "camera": "veranda",
    "start_time": 1794830193.963433,
    "end_time": 1794839770.372977,
    "data": {
        "box": [0.2609375, 0.21666666666666667, 0.178125, 0.6388888888888888],
        "path_data": [
            [[0.3484, 0.9111], 1794830194.136772],
            [[0.3203, 0.6556], 1794833213.546775],
            [[0.3438, 0.85], 1794839697.101112],
        ],
    },
}
# The same bike found again at 01:31 (event 1794859309.442572-1cf38f): its box at
# the alert, as a fraction of the 640x360 frame, and its path so far.
FOUND_AGAIN_ID = "1794859309.442572-1cf38f"
FOUND_AGAIN_START = 1794859309.442572
FOUND_AGAIN_AT = 1794859310.383333
FOUND_AGAIN_BOX = (0.2640625, 0.2666667, 0.4250000, 0.8472222)
FOUND_AGAIN_PATH = [(0.3469, 0.8444), (0.3453, 0.8472)]

# A car driving onto the veranda (event 1794842048.205673-4ijkq2): its path over
# its first six seconds, and its box where it got to.
ARRIVING_CAR_PATH = [(0.8063, 0.2889), (0.8, 0.3583), (0.7312, 0.4861), (0.6297, 0.6806)]
PARKED_CAR_BOX = (293 / 640, 56 / 360, 514 / 640, 245 / 360)


def found_again_is_parked() -> bool:
    earlier = sightings([PARKED_BIKE], FOUND_AGAIN_ID, FOUND_AGAIN_START)
    return still(FOUND_AGAIN_BOX, FOUND_AGAIN_PATH) and any(
        ended_here(s, FOUND_AGAIN_BOX, FOUND_AGAIN_AT) for s in earlier
    )


def test_the_bike_found_again_at_01_31_is_parked():
    assert found_again_is_parked()


def test_a_late_clip_on_a_long_parked_bike_is_parked():
    # The 18:16 alert: the clip came 50 minutes after Frigate first saw the bike,
    # its box flickering between its full height and its top part.
    box = (0.2609, 0.2167, 0.4391, 0.8556)
    path = path_points(PARKED_BIKE["data"]["path_data"])
    assert still(box, path)
    assert seen_for_a_while(PARKED_BIKE["start_time"], 1794833215.297105)


def test_a_vehicle_driving_in_is_not_still():
    assert not still(PARKED_CAR_BOX, ARRIVING_CAR_PATH)


def test_a_vehicle_first_seen_just_now_was_not_seen_for_a_while():
    assert not seen_for_a_while(FOUND_AGAIN_START, FOUND_AGAIN_AT)


def test_an_earlier_vehicle_somewhere_else_did_not_end_here():
    elsewhere = Sighting((0.05, 0.48, 0.24, 0.83), (0.15, 0.82), FOUND_AGAIN_START - 600)
    assert not ended_here(elsewhere, FOUND_AGAIN_BOX, FOUND_AGAIN_AT)


def test_an_earlier_vehicle_that_drove_off_did_not_end_here():
    # Same box, but its last point is far away: it was tracked leaving.
    (left,) = sightings([PARKED_BIKE], FOUND_AGAIN_ID, FOUND_AGAIN_START)
    drove_off = Sighting(left.box, (0.8, 0.3), left.end_time, True, left.start_time)
    assert not ended_here(drove_off, FOUND_AGAIN_BOX, FOUND_AGAIN_AT)


def test_an_earlier_vehicle_forgotten_after_a_day():
    (seen,) = sightings([PARKED_BIKE], FOUND_AGAIN_ID, FOUND_AGAIN_START)
    later = seen.end_time + MEMORY_SECONDS + 1
    assert ended_here(seen, FOUND_AGAIN_BOX, seen.end_time + MEMORY_SECONDS)
    assert not ended_here(seen, FOUND_AGAIN_BOX, later)


def test_a_vehicle_still_tracked_counts_however_long_ago_it_began():
    ongoing = Sighting((0.26, 0.22, 0.44, 0.86), (0.34, 0.85), None)
    assert ended_here(ongoing, FOUND_AGAIN_BOX, FOUND_AGAIN_AT + 10 * MEMORY_SECONDS)


def test_sightings_skip_this_event_later_ones_and_malformed_ones():
    later = {**PARKED_BIKE, "id": "later", "start_time": FOUND_AGAIN_START + 1}
    this = {**PARKED_BIKE, "id": FOUND_AGAIN_ID}
    no_box = {**PARKED_BIKE, "id": "no-box", "data": {"path_data": []}}
    no_path = {**PARKED_BIKE, "id": "no-path", "data": {"box": [0, 0, 1, 1]}}
    found = sightings(
        [PARKED_BIKE, later, this, no_box, no_path, "junk"], FOUND_AGAIN_ID, FOUND_AGAIN_START
    )
    assert found == [
        Sighting(
            (0.2609375, 0.21666666666666667, 0.4390625, 0.8555555555555555),
            (0.3438, 0.85),
            PARKED_BIKE["end_time"],
            stood_still=True,
            start_time=PARKED_BIKE["start_time"],
        )
    ]


def test_path_points_skip_malformed_entries():
    raw = [[[0.1, 0.2], 1.0], [[0.3], 2.0], "x", [], [[True, 0.5], 3.0], [[0.4, 0.5], 4.0]]
    assert path_points(raw) == [(0.1, 0.2), (0.4, 0.5)]
    assert path_points(None) == []


def test_iou():
    assert iou((0, 0, 1, 1), (0, 0, 1, 1)) == 1
    assert iou((0, 0, 1, 1), (2, 2, 3, 3)) == 0
    assert iou((0, 0, 2, 1), (1, 0, 3, 1)) == pytest.approx(1 / 3)


def test_vehicles():
    assert {"car", "motorcycle", "bicycle"} <= VEHICLES
    assert "person" not in VEHICLES


def run(base, *, parked, quiet=()):
    return decide(
        base=base,
        mode_name="I'm away",
        event_type="motorcycle",
        camera="veranda",
        quiet_entries=quiet,
        quiet_after_restart=False,
        burst=BurstWindow(600),
        pushes=PushBudget(600, 480),
        now=FOUND_AGAIN_AT,
        parked=parked,
    )


def test_a_parked_vehicle_is_review_only_with_its_reason():
    decision = run(CRITICAL, parked=found_again_is_parked())
    assert decision.delivery == REVIEW_ONLY
    assert not decision.is_sent
    assert decision.reason == "I'm away: critical; parked vehicle: review only"


def test_a_parked_vehicle_is_review_only_even_when_paused():
    pause = QuietEntry("q", PAUSE, ("motorcycle",), (), 0, FOUND_AGAIN_AT + 60)
    assert run(CRITICAL, parked=True, quiet=[pause]).delivery == REVIEW_ONLY


def test_a_vehicle_that_is_not_parked_alerts_as_before():
    assert run(CRITICAL, parked=False).delivery == CRITICAL


def check(label="motorcycle", box=FOUND_AGAIN_BOX, path=FOUND_AGAIN_PATH, events=(PARKED_BIKE,)):
    """is_parked for the 01:31 detection; `events` None means Frigate could not be read."""
    calls = []

    async def earlier():
        calls.append(True)
        return None if events is None else list(events)

    parked = asyncio.run(
        is_parked(
            label=label,
            box=box,
            path=path,
            event_id=FOUND_AGAIN_ID,
            start_time=FOUND_AGAIN_START,
            now=FOUND_AGAIN_AT,
            earlier=earlier,
        )
    )
    return parked, len(calls)


def test_is_parked_for_the_bike_found_again():
    assert check() == (True, 1)


def test_is_parked_alerts_as_usual_when_frigate_cannot_be_read():
    assert check(events=None) == (False, 1)


def test_is_parked_never_for_a_person_at_the_same_place():
    assert check(label="person") == (False, 0)


def test_is_parked_not_without_an_earlier_vehicle_there():
    assert check(events=()) == (False, 1)


def test_is_parked_not_for_a_vehicle_driving_in():
    assert check(box=PARKED_CAR_BOX, path=ARRIVING_CAR_PATH) == (False, 1)


def test_a_vehicle_moving_up_from_below_is_not_still():
    # Wheeled in from the bottom of the frame: its first point is a third of its
    # height below where it stands now.
    x1, y1, x2, y2 = FOUND_AGAIN_BOX
    path = [((x1 + x2) / 2, y2 + (y2 - y1) / 3), ((x1 + x2) / 2, y2)]
    assert not still(FOUND_AGAIN_BOX, path)
    assert check(path=path) == (False, 1)


# Two bikes parked side by side on the veranda on 2026-11-18 evening; Frigate kept
# losing them and swapping its track between them, ~150 alerts in six hours. At
# 21:00:31 (event 1795015417.825836-cjr7gk) it stood on the right one, its path
# hopping between both.
SWAP_ID = "1795015417.825836-cjr7gk"
SWAP_START = 1795015417.825836
SWAP_AT = 1795015431.3719614
RIGHT_BIKE_BOX = (264 / 640, 187 / 360, 319 / 640, 357 / 360)
SWAP_PATH = [(0.1656, 0.7889), (0.4609, 0.9861), (0.1672, 0.8), (0.1406, 0.9111)]
LEFT_BIKE = {
    "id": "left",
    "start_time": 1795015070.807349,
    "end_time": 1795015074.312521,
    "data": {
        "box": [0.0437, 0.5028, 0.1922, 0.4139],
        "path_data": [[[0.1391, 0.9167], 1795015071.0], [[0.1672, 0.7611], 1795015072.0]],
    },
}
RIGHT_BIKE = {
    "id": "right",
    "start_time": 1795015101.954169,
    "end_time": 1795015138.964182,
    "data": {
        "box": [0.4125, 0.5167, 0.0859, 0.475],
        "path_data": [[[0.4547, 0.9917], 1795015102.0], [[0.4547, 0.9917], 1795015110.0]],
    },
}


def check_swap(path=SWAP_PATH, events=(LEFT_BIKE, RIGHT_BIKE)):
    async def earlier():
        return list(events)

    return asyncio.run(
        is_parked(
            label="motorcycle",
            box=RIGHT_BIKE_BOX,
            path=path,
            event_id=SWAP_ID,
            start_time=SWAP_START,
            now=SWAP_AT,
            earlier=earlier,
        )
    )


def test_a_track_jumping_between_bikes_parked_side_by_side_is_parked():
    assert not still(RIGHT_BIKE_BOX, SWAP_PATH)
    assert check_swap()


def test_a_jump_to_a_place_no_vehicle_stood_still_is_not_parked():
    # Without the left bike's earlier event, nothing ever stood where half the path is.
    assert not check_swap(events=(RIGHT_BIKE,))


def test_a_vehicle_that_moved_is_no_parked_spot():
    left = sightings([LEFT_BIKE], SWAP_ID, SWAP_START)[0]
    assert parked_spot(left, SWAP_AT)
    moved = {
        **LEFT_BIKE,
        "data": {**LEFT_BIKE["data"], "path_data": [[[0.9, 0.3], 1.0], [[0.1391, 0.9167], 2.0]]},
    }
    (drove_in,) = sightings([moved], SWAP_ID, SWAP_START)
    assert not parked_spot(drove_in, SWAP_AT)
    assert not check_swap(events=(moved, RIGHT_BIKE))


def test_a_parked_spot_is_forgotten_after_a_day():
    (left,) = sightings([LEFT_BIKE], SWAP_ID, SWAP_START)
    assert not parked_spot(left, left.end_time + MEMORY_SECONDS + 1)


def test_a_vehicle_arriving_past_parked_ones_is_not_on_spots():
    spots = [RIGHT_BIKE_BOX, sightings([LEFT_BIKE], SWAP_ID, SWAP_START)[0].box]
    assert on_spots(SWAP_PATH, spots)
    assert not on_spots([(0.8, 0.3), (0.6, 0.6), *SWAP_PATH], spots)


# The car driving onto the veranda on 2026-11-16 20:44 (event 1794842048.205673-4ijkq2),
# 0.9 s after Frigate first saw it at the gate: one still-looking point so far.
GATE_BOX = (0.78, 0.181, 0.834, 0.347)
GATE_PATH = [(0.806, 0.289), (0.806, 0.292)]


def lost_at_gate(ended_ago, stood_for):
    """An earlier vehicle event that stood still at the gate for `stood_for` seconds
    and ended `ended_ago` seconds before the car came."""
    end = FOUND_AGAIN_AT - ended_ago
    return {
        "id": "gate",
        "start_time": end - stood_for,
        "end_time": end,
        "data": {
            "box": [0.78, 0.181, 0.054, 0.166],
            "path_data": [[[0.806, 0.345], end - stood_for], [[0.806, 0.345], end]],
        },
    }


def test_a_vehicle_lost_at_the_gate_hours_ago_does_not_quiet_one_coming_in():
    # Vehicles get lost where they come in; only a recent one, or one that stood
    # there a while, says something is parked there.
    arriving = dict(box=GATE_BOX, path=GATE_PATH)
    assert check(**arriving, events=[lost_at_gate(282 * 60, 3)]) == (False, 1)
    assert check(**arriving, events=[lost_at_gate(RECENT_SECONDS - 60, 3)]) == (True, 1)
    assert check(**arriving, events=[lost_at_gate(282 * 60, 600)]) == (True, 1)


def test_a_box_with_only_the_top_of_a_parked_scooter_is_the_same_place():
    # Live boxes on 2026-11-19 01:24 (640x360): the scooter on the left, and its box
    # flickering to only its top part.
    whole = (27 / 640, 180 / 360, 151 / 640, 331 / 360)
    top = (63 / 640, 180 / 360, 151 / 640, 283 / 360)
    assert iou(whole, top) < 0.5
    assert same_place(whole, top)
    assert not same_place(whole, (200 / 640, 180 / 360, 300 / 640, 331 / 360))


# The veranda's zones as Frigate's api/config gives them on 2026-11-24.
VERANDA_ZONES = {
    "veranda_parking": {
        "enabled": True,
        "coordinates": "0,0.44,0.64,0.075,0.96,0.29,0.874,1,0,1",
        "objects": ["car", "motorcycle"],
    }
}
PARKING = parking_zones(VERANDA_ZONES)

# The scooter among five parked bikes, pushed critical at 2026-11-24 01:30:20
# (event 1795463987.422285-jrefbd): Frigate's track hopped between it and the bike
# in front at the bottom of the frame. Its box at the alert (640x360) and its path.
SCOOTER_ID = "1795463987.422285-jrefbd"
SCOOTER_START = 1795463987.422285
SCOOTER_AT = 1795464020.8223052
SCOOTER_BOX = (212 / 640, 147 / 360, 293 / 640, 301 / 360)
SCOOTER_PATH = [
    (0.5344, 0.9972),
    (0.5297, 0.9972),
    (0.4594, 0.9972),
    (0.5312, 0.9972),
    (0.4578, 0.9972),
    (0.5328, 0.9972),
    (0.3328, 0.8917),
    (0.3937, 0.8361),
]
# The car coming up the driveway at 2026-11-23 12:42:43 (event
# 1795417958.287807-jahfs0): first seen past the parked car, outside the zone.
DRIVEWAY_CAR_BOX = (287 / 640, 59 / 360, 562 / 640, 254 / 360)
DRIVEWAY_CAR_PATH = [(0.7734, 0.1167), (0.7719, 0.1194), (0.7734, 0.1778), (0.8047, 0.2361)]


def check_zone(label="motorcycle", box=SCOOTER_BOX, path=SCOOTER_PATH, zones=PARKING):
    """is_parked for the 01:30 detection with no earlier events; how many times it
    asked Frigate for them."""
    calls = []

    async def earlier():
        calls.append(True)
        return []

    parked = asyncio.run(
        is_parked(
            label=label,
            box=box,
            path=path,
            event_id=SCOOTER_ID,
            start_time=SCOOTER_START,
            now=SCOOTER_AT,
            earlier=earlier,
            zones=zones,
        )
    )
    return parked, len(calls)


def test_the_scooter_pushed_at_01_30_only_ever_seen_in_the_parking_zone_is_parked():
    assert not still(SCOOTER_BOX, SCOOTER_PATH)
    assert check_zone() == (True, 0)


def test_the_bike_found_again_at_22_14_in_the_parking_zone_is_parked():
    # 2026-11-23 22:14:12 (event 1795450479.448002-m2gt5n): half an hour of a track
    # hopping between two bikes along the bottom of the frame.
    path = [(0.3109, 0.9972), (0.4562, 0.9972), (0.2922, 0.9972), (0.3016, 0.9944)] * 15
    box = (206 / 640, 147 / 360, 298 / 640, 302 / 360)
    assert check_zone(box=box, path=[*path, (0.3812, 0.8417)]) == (True, 0)


def test_a_car_coming_up_the_driveway_goes_on_to_the_usual_check():
    assert not in_parking_zones(DRIVEWAY_CAR_BOX, DRIVEWAY_CAR_PATH, PARKING)
    assert check_zone(label="car", box=DRIVEWAY_CAR_BOX, path=DRIVEWAY_CAR_PATH) == (False, 1)


def test_a_person_in_the_parking_zone_is_never_parked():
    assert check_zone(label="person") == (False, 0)


def test_without_a_parking_zone_the_usual_check_decides():
    assert check_zone(zones=()) == (False, 1)
    assert check_zone(zones=parking_zones({})) == (False, 1)


def test_where_a_vehicle_stands_now_counts_as_seen():
    # No path yet: where it stands decides, inside the zone or out in the driveway.
    assert in_parking_zones(SCOOTER_BOX, [], PARKING)
    assert not in_parking_zones(DRIVEWAY_CAR_BOX, [], [[(0, 0.75), (1, 0.75), (1, 1), (0, 1)]])


def test_a_point_on_the_zones_edge_is_inside():
    (zone,) = PARKING
    assert in_zone((0.4, 1.0), zone)
    assert in_zone((0.0, 0.7), zone)
    assert not in_zone((0.4, 1.01), zone)
    assert not in_zone((0.77, 0.13), zone)


def test_parking_zones_are_the_enabled_ones_named_parking():
    zones = {
        "veranda_parking": {"coordinates": ["0,0.5", "1,0.5", "1,1", "0,1"]},
        "gate": {"coordinates": "0,0,1,0,1,1"},
        "old_parking": {"enabled": False, "coordinates": "0,0,1,0,1,1"},
        "odd_parking": {"coordinates": "0,0,1,0,1"},
        "short_parking": {"coordinates": "0,0,1,1"},
        "text_parking": {"coordinates": "a,b,c,d,e,f"},
        "none_parking": {},
        "junk_parking": "x",
    }
    assert parking_zones(zones) == [[(0, 0.5), (1, 0.5), (1, 1), (0, 1)]]
    assert parking_zones(None) == []
