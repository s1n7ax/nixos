from __future__ import annotations

import pytest

from core.quiet import (
    DND,
    PAUSE,
    SNOOZE,
    QuietEntry,
    new_entries,
    next_expiry,
    running,
    strongest,
)

NOW = 1_000_000.0
HOUR = 3600.0


def entry(kind, types, cameras=(), ends_in=HOUR, id_="e"):
    return QuietEntry(id_, kind, tuple(types), tuple(cameras), NOW, NOW + ends_in)


def test_all_cameras_match_any_camera_and_sensors():
    e = entry(PAUSE, ["person", "door"])
    assert e.matches("person", "cam_a")
    assert e.matches("person", "cam_b")
    assert e.matches("door", None)
    assert not e.matches("car", "cam_a")


def test_camera_limited_entry_matches_only_its_cameras():
    e = entry(DND, ["person"], ["cam_a"])
    assert e.matches("person", "cam_a")
    assert not e.matches("person", "cam_b")
    assert not e.matches("car", "cam_a")


def test_camera_limited_entry_never_matches_sensor_events():
    e = entry(PAUSE, ["door"], ["cam_a"])
    assert not e.matches("door", None)


def test_expiry():
    e = entry(SNOOZE, ["person"], ends_in=HOUR)
    assert e.is_running(NOW)
    assert e.is_running(NOW + HOUR - 1)
    assert not e.is_running(NOW + HOUR)
    assert running([e], NOW + HOUR) == []
    assert running([e], NOW) == [e]


def test_next_expiry_skips_ended_entries():
    a = entry(PAUSE, ["person"], ends_in=HOUR, id_="a")
    b = entry(PAUSE, ["car"], ends_in=2 * HOUR, id_="b")
    assert next_expiry([a, b], NOW) == NOW + HOUR
    assert next_expiry([a, b], NOW + HOUR) == NOW + 2 * HOUR
    assert next_expiry([a, b], NOW + 2 * HOUR) is None
    assert next_expiry([], NOW) is None


@pytest.mark.parametrize(
    ("kinds", "expected"),
    [
        ([DND], DND),
        ([SNOOZE], SNOOZE),
        ([PAUSE], PAUSE),
        ([DND, SNOOZE], SNOOZE),
        ([SNOOZE, DND], SNOOZE),
        ([DND, PAUSE], PAUSE),
        ([SNOOZE, PAUSE, DND], PAUSE),
    ],
)
def test_quietest_wins(kinds, expected):
    entries = [entry(kind, ["person"], id_=f"{i}") for i, kind in enumerate(kinds)]
    assert strongest(entries, "person", "cam_a", NOW).kind == expected


def test_strongest_ignores_ended_and_unmatched_entries():
    ended = entry(PAUSE, ["person"], ends_in=-1, id_="ended")
    other_type = entry(PAUSE, ["car"], id_="car")
    other_cam = entry(PAUSE, ["person"], ["cam_b"], id_="cam_b")
    dnd = entry(DND, ["person"], id_="dnd")
    assert strongest([ended, other_type, other_cam, dnd], "person", "cam_a", NOW) is dnd
    assert strongest([ended, other_type, other_cam], "person", "cam_a", NOW) is None


def test_round_trip():
    e = entry(DND, ["person", "fire_alarm"], ["cam_a"])
    assert QuietEntry.from_dict(e.as_dict()) == e


def test_new_entries_without_cameras(make_id):
    entries = new_entries(SNOOZE, ["person", "door", "person"], [], 2, NOW, make_id)
    assert entries == [QuietEntry("id1", SNOOZE, ("person", "door"), (), NOW, NOW + 2 * HOUR)]


def test_new_entries_split_sensor_types_off_camera_limits(make_id):
    entries = new_entries(PAUSE, ["person", "door", "motion"], ["cam_a"], 1, NOW, make_id)
    assert entries == [
        QuietEntry("id1", PAUSE, ("person",), ("cam_a",), NOW, NOW + HOUR),
        QuietEntry("id2", PAUSE, ("door", "motion"), (), NOW, NOW + HOUR),
    ]


def test_new_entries_only_sensor_types_with_cameras(make_id):
    entries = new_entries(DND, ["door"], ["cam_a"], 1, NOW, make_id)
    assert entries == [QuietEntry("id1", DND, ("door",), (), NOW, NOW + HOUR)]


@pytest.mark.parametrize(
    ("kind", "types", "hours"),
    [("mute", ["person"], 1), (PAUSE, [], 1), (PAUSE, ["person"], 0), (PAUSE, ["person"], -1)],
)
def test_new_entries_rejects_bad_requests(kind, types, hours, make_id):
    with pytest.raises(ValueError):
        new_entries(kind, types, [], hours, NOW, make_id)
