from __future__ import annotations

from datetime import time

import pytest

from core.policy import (
    CRITICAL,
    DETECTION,
    DOOR,
    LEVELS,
    MOTION,
    NONE,
    REGULAR,
    REVIEW_ONLY,
    SILENT,
    SOUND,
    Mode,
    active_mode,
    base_level,
    is_asleep,
    is_night,
)
from modes import ALL_AWAY, HOME, I_AWAY, LADDER, WE_AWAY

MIDNIGHT = time(0, 0)
FIVE_AM = time(5, 0)

# (mode, kind, top floor) -> level, straight from the requirement's Modes section.
MODE_TABLE = {
    (I_AWAY, DETECTION, True): CRITICAL,
    (I_AWAY, DETECTION, False): CRITICAL,
    (I_AWAY, SOUND, True): REGULAR,
    (I_AWAY, SOUND, False): REGULAR,
    (I_AWAY, DOOR, True): NONE,
    (I_AWAY, DOOR, False): NONE,
    (I_AWAY, MOTION, True): NONE,
    (I_AWAY, MOTION, False): NONE,
    (WE_AWAY, DETECTION, True): CRITICAL,
    (WE_AWAY, DETECTION, False): CRITICAL,
    (WE_AWAY, SOUND, True): REGULAR,
    (WE_AWAY, SOUND, False): REGULAR,
    (WE_AWAY, DOOR, True): CRITICAL,
    (WE_AWAY, DOOR, False): NONE,
    (WE_AWAY, MOTION, True): CRITICAL,
    (WE_AWAY, MOTION, False): NONE,
    (ALL_AWAY, DETECTION, True): CRITICAL,
    (ALL_AWAY, DETECTION, False): CRITICAL,
    (ALL_AWAY, SOUND, True): REGULAR,
    (ALL_AWAY, SOUND, False): REGULAR,
    (ALL_AWAY, DOOR, True): CRITICAL,
    (ALL_AWAY, DOOR, False): CRITICAL,
    (ALL_AWAY, MOTION, True): CRITICAL,
    (ALL_AWAY, MOTION, False): SILENT,
}


@pytest.mark.parametrize(("mode", "kind", "top_floor"), list(MODE_TABLE))
def test_mode_levels(mode, kind, top_floor):
    level = base_level(kind, mode=mode, home=HOME, top_floor=top_floor, asleep=False, night=False)
    assert level == MODE_TABLE[(mode, kind, top_floor)]


@pytest.mark.parametrize("mode", LADDER)
@pytest.mark.parametrize(("asleep", "night"), [(True, False), (False, True), (True, True)])
def test_away_modes_ignore_sleep_and_night(mode, asleep, night):
    for kind in (DETECTION, SOUND, DOOR, MOTION):
        for top in (True, False):
            level = base_level(
                kind, mode=mode, home=HOME, top_floor=top, asleep=asleep, night=night
            )
            assert level == MODE_TABLE[(mode, kind, top)]


@pytest.mark.parametrize(
    ("asleep", "night", "expected"),
    [
        (False, False, REGULAR),
        (True, False, CRITICAL),
        (False, True, CRITICAL),
        (True, True, CRITICAL),
    ],
)
def test_home_detection(asleep, night, expected):
    level = base_level(DETECTION, mode=None, home=HOME, top_floor=False, asleep=asleep, night=night)
    assert level == expected


@pytest.mark.parametrize(("asleep", "night"), [(False, False), (True, False), (True, True)])
@pytest.mark.parametrize("top_floor", [True, False])
def test_home_sound_is_review_only(asleep, night, top_floor):
    level = base_level(SOUND, mode=None, home=HOME, top_floor=top_floor, asleep=asleep, night=night)
    assert level == REVIEW_ONLY


def test_review_only_is_a_level_between_none_and_silent():
    assert LEVELS.index(NONE) < LEVELS.index(REVIEW_ONLY) < LEVELS.index(SILENT)


@pytest.mark.parametrize("kind", [DOOR, MOTION])
@pytest.mark.parametrize("top_floor", [True, False])
def test_home_sensors_are_not_armed(kind, top_floor):
    assert base_level(kind, mode=None, home=HOME, top_floor=top_floor, asleep=True, night=True) == (
        NONE
    )


def test_unknown_kind_raises():
    with pytest.raises(ValueError):
        base_level("smoke", mode=WE_AWAY, home=HOME, top_floor=True, asleep=False, night=False)
    with pytest.raises(ValueError):
        base_level("smoke", mode=None, home=HOME, top_floor=True, asleep=False, night=False)


def test_mode_levels_list_every_level_of_a_kind():
    mode = Mode(
        name="Made up",
        entity="input_boolean.mode_x",
        detection=CRITICAL,
        sound=REGULAR,
        door_top=SILENT,
        door_other=NONE,
        motion_top=REVIEW_ONLY,
        motion_other=CRITICAL,
    )
    assert mode.levels(DETECTION) == (CRITICAL,)
    assert mode.levels(SOUND) == (REGULAR,)
    assert mode.levels(DOOR) == (SILENT, NONE)
    assert mode.levels(MOTION) == (REVIEW_ONLY, CRITICAL)


def test_mode_levels_unknown_kind_raises():
    with pytest.raises(ValueError):
        WE_AWAY.levels("smoke")


@pytest.mark.parametrize(
    ("on", "expected"),
    [
        (set(), None),
        ({I_AWAY.entity}, I_AWAY),
        ({WE_AWAY.entity}, WE_AWAY),
        ({ALL_AWAY.entity}, ALL_AWAY),
        ({I_AWAY.entity, WE_AWAY.entity}, WE_AWAY),
        ({I_AWAY.entity, ALL_AWAY.entity}, ALL_AWAY),
        ({I_AWAY.entity, WE_AWAY.entity, ALL_AWAY.entity}, ALL_AWAY),
    ],
)
def test_highest_mode_on_wins(on, expected):
    assert active_mode(LADDER, lambda entity: entity in on) == expected


@pytest.mark.parametrize(
    ("state", "expected"),
    [
        ("95", True),
        ("90", True),
        ("90.0", True),
        ("89.9", False),
        ("0", False),
        ("unknown", False),
        ("unavailable", False),
        (None, False),
        ("", False),
        ("nan", False),
    ],
)
def test_is_asleep(state, expected):
    assert is_asleep(state, 90) is expected


@pytest.mark.parametrize(
    ("now", "expected"),
    [
        (time(0, 0), True),
        (time(2, 30), True),
        (time(4, 59, 59), True),
        (time(5, 0), False),
        (time(12, 0), False),
        (time(23, 59, 59), False),
    ],
)
def test_night_midnight_to_five(now, expected):
    assert is_night(now, MIDNIGHT, FIVE_AM) is expected


@pytest.mark.parametrize(
    ("now", "expected"),
    [(time(22, 0), True), (time(23, 30), True), (time(3, 0), True), (time(6, 0), False)],
)
def test_night_wrapping_past_midnight(now, expected):
    assert is_night(now, time(22, 0), time(6, 0)) is expected


def test_night_with_equal_bounds_is_never():
    assert is_night(time(0, 0), MIDNIGHT, MIDNIGHT) is False
