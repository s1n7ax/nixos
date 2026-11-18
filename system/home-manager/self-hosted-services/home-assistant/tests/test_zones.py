from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from zones import (
    BED,
    BED_SLEEP,
    DEFAULT_AIMS,
    FAN_HIGH,
    FAN_LOW,
    MY_DESK,
    SPOTS,
    WIFE_DESK,
    asleep_since,
    current_step,
    is_manual,
    last_moment,
    plan,
)

COLOMBO = timezone(timedelta(hours=5, minutes=30))


def at(day: int, hour: int, minute: int = 0) -> datetime:
    return datetime(2026, 11, day, hour, minute, tzinfo=COLOMBO)


@pytest.mark.parametrize(
    ("now", "spots"),
    [
        (at(20, 8), {BED, WIFE_DESK}),
        (at(20, 9), set(SPOTS)),
        (at(20, 9, 45), set(SPOTS)),
        (at(20, 10), {BED, WIFE_DESK}),
        (at(20, 17, 59), {BED, WIFE_DESK}),
        (at(20, 18), set(SPOTS)),
        (at(20, 22), {BED, MY_DESK}),
        (at(21, 1), {BED, MY_DESK}),
        (at(21, 7, 59), {BED, MY_DESK}),
    ],
)
def test_schedule(now, spots):
    assert current_step(now, None).spots == spots


def test_last_moment_before_eight_is_yesterdays_night():
    assert last_moment(at(21, 3))[0] == at(20, 22)


def test_awake_without_signal_until_the_fallback():
    assert asleep_since(at(21, 1, 29), None, None) is None
    assert asleep_since(at(21, 1, 30), None, None) == at(21, 1, 30)


def test_phone_signal_after_eleven_starts_sleep():
    assert asleep_since(at(20, 23, 40), None, 95) == at(20, 23, 40)


def test_phone_signal_before_eleven_is_ignored():
    assert asleep_since(at(20, 22, 30), None, 99) is None


def test_low_confidence_is_not_sleep():
    assert asleep_since(at(21, 0, 30), None, 40) is None


def test_sleep_is_kept_through_the_night():
    since = at(21, 0, 10)
    assert asleep_since(at(21, 5), since, 10) == since


def test_hours_after_fallback_report_the_fallback_time():
    # HA was down over 01:30: the sleep still started then.
    assert asleep_since(at(21, 3), None, None) == at(21, 1, 30)


def test_sleep_ends_at_eight():
    assert asleep_since(at(21, 8), at(21, 0, 30), 99) is None
    assert current_step(at(21, 8), None).spots == {BED, WIFE_DESK}


def test_sleep_step_is_bed_only_and_its_own_step():
    since = at(21, 0, 50)
    step = current_step(at(21, 1), since)
    assert step.spots == {BED}
    assert step.key != current_step(at(21, 0, 40), None).key


def test_yesterdays_sleep_does_not_leak_into_the_day():
    assert current_step(at(21, 12), at(21, 1, 30)).spots == {BED, WIFE_DESK}


def test_one_spot_is_aimed_at():
    p = plan(at(20, 12), {MY_DESK}, DEFAULT_AIMS, None)
    assert p.targets == (MY_DESK,)
    assert (p.vertical, p.horizontal) == DEFAULT_AIMS[MY_DESK]
    assert p.fan == FAN_HIGH


def test_several_spots_sweep_every_two_minutes_in_order():
    spots = {BED, MY_DESK, WIFE_DESK}
    seen = [plan(at(20, 12, m), spots, DEFAULT_AIMS, None).target for m in range(0, 12, 2)]
    assert seen[:3] in (
        [MY_DESK, BED, WIFE_DESK],
        [BED, WIFE_DESK, MY_DESK],
        [WIFE_DESK, MY_DESK, BED],
    )
    assert seen[:3] == seen[3:]


def test_no_spot_means_no_plan():
    assert plan(at(20, 12), set(), DEFAULT_AIMS, None) is None


def test_asleep_the_bed_gets_its_sleep_aim_on_high_fan():
    since = at(21, 1)
    p = plan(at(21, 2), {BED}, DEFAULT_AIMS, since)
    assert p.target == BED_SLEEP
    assert (p.vertical, p.horizontal) == DEFAULT_AIMS[BED_SLEEP]
    assert p.fan == FAN_HIGH


def test_three_hours_into_sleep_the_fan_goes_low():
    since = at(21, 1)
    assert plan(at(21, 3, 59), {BED}, DEFAULT_AIMS, since).fan == FAN_HIGH
    assert plan(at(21, 4), {BED}, DEFAULT_AIMS, since).fan == FAN_LOW


def test_tuned_aims_are_used():
    aims = {**DEFAULT_AIMS, MY_DESK: ("V2", "H4")}
    p = plan(at(20, 12), {MY_DESK}, aims, None)
    assert (p.vertical, p.horizontal) == ("V2", "H4")


NOW = at(20, 12)
OLD = ("high", "V1", "H5")
NEW = ("high", "V3", "H1")


def test_change_long_after_a_command_is_manual():
    assert is_manual(OLD, NEW, OLD, NOW - timedelta(minutes=5), NOW)


def test_change_with_no_command_yet_is_manual():
    assert is_manual(OLD, NEW, None, None, NOW)


def test_report_of_the_command_is_not_manual():
    assert not is_manual(OLD, NEW, NEW, NOW - timedelta(minutes=5), NOW)


def test_change_right_after_a_command_is_not_manual():
    assert not is_manual(OLD, ("high", "V3", "H5"), NEW, NOW - timedelta(seconds=10), NOW)


def test_coming_back_on_or_online_is_not_manual():
    assert not is_manual(None, NEW, OLD, None, NOW)
    assert not is_manual(OLD, None, OLD, None, NOW)


def test_unchanged_setting_is_not_manual():
    assert not is_manual(OLD, OLD, NEW, None, NOW)
