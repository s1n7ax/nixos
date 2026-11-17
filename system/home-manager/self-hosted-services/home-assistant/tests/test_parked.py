"""Parked vehicles that Frigate found again, from the live alerts that started this."""

from __future__ import annotations

import pytest

from core.burst import BurstWindow
from core.decide import decide
from core.parked import (
    MEMORY_SECONDS,
    VEHICLES,
    Sighting,
    ended_here,
    iou,
    path_points,
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
    drove_off = Sighting(left.box, (0.8, 0.3), left.end_time)
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
