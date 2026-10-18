"""The requirement's acceptance criteria, run through policy and decide together."""

from __future__ import annotations

from datetime import time

import pytest

from core.burst import BurstWindow
from core.decide import PAUSED, POPUP, decide
from core.policy import (
    CRITICAL,
    DETECTION,
    DOOR,
    HOME,
    MOTION,
    NONE,
    REGULAR,
    SILENT,
    SOUND,
    active_mode,
    base_level,
    is_asleep,
    is_night,
)
from core.quiet import DND, PAUSE, SNOOZE, QuietEntry
from modes import ALL_AWAY, I_AWAY, LADDER, WE_AWAY
from modes import HOME as HOME_RULES

NOW = 2_000_000.0
WINDOW = 600.0
NIGHT = (time(0, 0), time(5, 0))


def run(
    kind,
    event_type=None,
    *,
    on=(),
    camera="cam_a",
    top_floor=False,
    sleep="0",
    clock=time(12, 0),
    quiet=(),
    restart=False,
    burst=None,
    now=NOW,
):
    mode = active_mode(LADDER, lambda entity: entity in on)
    base = base_level(
        kind,
        mode=mode,
        home=HOME_RULES,
        top_floor=top_floor,
        asleep=is_asleep(sleep, 90),
        night=is_night(clock, *NIGHT),
    )
    burst = burst if burst is not None else BurstWindow(WINDOW)
    decision = decide(
        base=base,
        mode_name=mode.name if mode else HOME,
        event_type=event_type or kind,
        camera=camera if kind in (DETECTION, SOUND) else None,
        quiet_entries=quiet,
        quiet_after_restart=restart,
        burst=burst,
        now=now,
    )
    if decision.rings:
        burst.record(event_type or kind, now)
    return decision


def quiet(kind, types, cameras=(), id_="q"):
    return QuietEntry(id_, kind, tuple(types), tuple(cameras), NOW - 60, NOW + 3600)


# Modes: a detection, a sound and door/motion events in each mode.
@pytest.mark.parametrize(
    ("on", "kind", "top_floor", "expected"),
    [
        ((), DETECTION, False, REGULAR),
        ((), SOUND, False, SILENT),
        ((), DOOR, True, NONE),
        ((), MOTION, True, NONE),
        ((I_AWAY.entity,), DETECTION, False, CRITICAL),
        ((I_AWAY.entity,), SOUND, False, REGULAR),
        ((I_AWAY.entity,), DOOR, True, NONE),
        ((I_AWAY.entity,), MOTION, True, NONE),
        ((WE_AWAY.entity,), DETECTION, False, CRITICAL),
        ((WE_AWAY.entity,), SOUND, False, REGULAR),
        ((WE_AWAY.entity,), DOOR, True, CRITICAL),
        ((WE_AWAY.entity,), MOTION, True, CRITICAL),
        ((WE_AWAY.entity,), DOOR, False, NONE),
        ((WE_AWAY.entity,), MOTION, False, NONE),
        ((ALL_AWAY.entity,), DETECTION, False, CRITICAL),
        ((ALL_AWAY.entity,), SOUND, False, REGULAR),
        ((ALL_AWAY.entity,), DOOR, True, CRITICAL),
        ((ALL_AWAY.entity,), DOOR, False, CRITICAL),
        ((ALL_AWAY.entity,), MOTION, True, CRITICAL),
        ((ALL_AWAY.entity,), MOTION, False, SILENT),
        ((I_AWAY.entity, WE_AWAY.entity, ALL_AWAY.entity), MOTION, False, SILENT),
    ],
)
def test_levels_per_mode(on, kind, top_floor, expected):
    event_type = "person" if kind == DETECTION else "bark" if kind == SOUND else kind
    assert run(kind, event_type, on=on, top_floor=top_floor).delivery == expected


# Home: asleep or between 12 AM and 5 AM rings critical; otherwise regular.
@pytest.mark.parametrize(
    ("sleep", "clock", "expected"),
    [
        ("95", time(14, 0), CRITICAL),
        ("0", time(0, 30), CRITICAL),
        ("0", time(4, 59), CRITICAL),
        ("0", time(5, 0), REGULAR),
        ("unknown", time(14, 0), REGULAR),
        ("89", time(23, 59), REGULAR),
    ],
)
def test_home_asleep_and_night(sleep, clock, expected):
    assert run(DETECTION, "person", sleep=sleep, clock=clock).delivery == expected


def test_second_critical_of_a_type_within_window_pops_up():
    burst = BurstWindow(WINDOW)
    on = (I_AWAY.entity,)
    assert run(DETECTION, "person", on=on, burst=burst, now=NOW).delivery == CRITICAL
    assert run(DETECTION, "person", on=on, burst=burst, now=NOW + 1).delivery == POPUP
    assert run(DETECTION, "person", on=on, burst=burst, now=NOW + WINDOW - 1).delivery == POPUP
    # Another type keeps its own window.
    assert run(DETECTION, "car", on=on, burst=burst, now=NOW + 2).delivery == CRITICAL
    # A popup does not restart the window; the next ring is 10 minutes after the last ring.
    assert run(DETECTION, "person", on=on, burst=burst, now=NOW + WINDOW).delivery == CRITICAL


def test_regular_and_silent_never_use_the_window():
    burst = BurstWindow(WINDOW)
    assert run(DETECTION, "person", burst=burst).delivery == REGULAR
    assert run(DETECTION, "person", burst=burst, now=NOW + 1).delivery == REGULAR
    assert burst.as_dict() == {}


def test_pause_logs_paused_and_sends_nothing():
    d = run(DETECTION, "person", on=(I_AWAY.entity,), quiet=[quiet(PAUSE, ["person"])])
    assert d.delivery == PAUSED
    assert d.is_alert and not d.is_sent
    assert d.quiet_id == "q"


def test_pause_limited_to_cameras():
    q = [quiet(PAUSE, ["person"], ["cam_a"])]
    on = (I_AWAY.entity,)
    assert run(DETECTION, "person", on=on, quiet=q, camera="cam_a").delivery == PAUSED
    assert run(DETECTION, "person", on=on, quiet=q, camera="cam_b").delivery == CRITICAL


def test_pause_of_a_sensor_type():
    on = (ALL_AWAY.entity,)
    assert run(DOOR, on=on, top_floor=True, quiet=[quiet(PAUSE, ["door"])]).delivery == PAUSED


def test_snooze_makes_the_type_silent():
    q = [quiet(SNOOZE, ["person"])]
    on = (ALL_AWAY.entity,)
    assert run(DETECTION, "person", on=on, quiet=q).delivery == SILENT
    assert run(DETECTION, "car", on=on, quiet=q).delivery == CRITICAL


def test_dnd_on_one_camera_quiets_only_that_type_there():
    q = [quiet(DND, ["person"], ["cam_a"])]
    on = (I_AWAY.entity,)
    assert run(DETECTION, "person", on=on, quiet=q, camera="cam_a").delivery == REGULAR
    assert run(DETECTION, "car", on=on, quiet=q, camera="cam_a").delivery == CRITICAL
    assert run(DETECTION, "motorcycle", on=on, quiet=q, camera="cam_a").delivery == CRITICAL
    assert run(DETECTION, "person", on=on, quiet=q, camera="cam_b").delivery == CRITICAL


def test_dnd_leaves_regular_and_silent_alone():
    q = [quiet(DND, ["bark", "motion"])]
    assert run(SOUND, "bark", on=(I_AWAY.entity,), quiet=q).delivery == REGULAR
    assert run(MOTION, on=(ALL_AWAY.entity,), quiet=q).delivery == SILENT


def test_quietest_entry_wins():
    on = (I_AWAY.entity,)
    both = [quiet(DND, ["person"], id_="dnd"), quiet(SNOOZE, ["person"], id_="snooze")]
    assert run(DETECTION, "person", on=on, quiet=both).delivery == SILENT
    every = [*both, quiet(PAUSE, ["person"], id_="pause")]
    assert run(DETECTION, "person", on=on, quiet=every).delivery == PAUSED


def test_quiet_after_restart_sends_silent():
    on = (WE_AWAY.entity,)
    assert run(DETECTION, "person", on=on, restart=True).delivery == SILENT
    assert run(DOOR, on=on, top_floor=True, restart=True).delivery == SILENT
    # A pause still wins, and sensors that are not armed stay quiet.
    q = [quiet(PAUSE, ["person"])]
    assert run(DETECTION, "person", on=on, restart=True, quiet=q).delivery == PAUSED
    assert run(DOOR, on=on, top_floor=False, restart=True).delivery == NONE


def test_quieted_critical_does_not_restart_the_window():
    burst = BurstWindow(WINDOW)
    on = (I_AWAY.entity,)
    q = [quiet(DND, ["person"])]
    assert run(DETECTION, "person", on=on, quiet=q, burst=burst).delivery == REGULAR
    assert run(DETECTION, "person", on=on, burst=burst, now=NOW + 1).delivery == CRITICAL


def test_ended_quiet_entry_no_longer_applies():
    q = [QuietEntry("q", SNOOZE, ("person",), (), NOW - 7200, NOW - 3600)]
    assert run(DETECTION, "person", on=(I_AWAY.entity,), quiet=q).delivery == CRITICAL


def test_none_is_not_an_alert():
    d = run(MOTION, on=(WE_AWAY.entity,), top_floor=False, quiet=[quiet(PAUSE, ["motion"])])
    assert d.delivery == NONE
    assert not d.is_alert


def test_reason_names_each_step():
    burst = BurstWindow(WINDOW, {"person": NOW - 1})
    d = run(DETECTION, "person", on=(I_AWAY.entity,), burst=burst)
    assert d.reason == "I'm away: critical; rang in the last burst window: popup"


def test_unknown_level_raises():
    with pytest.raises(ValueError):
        decide(
            base="loud",
            mode_name="Home",
            event_type="person",
            camera="cam_a",
            quiet_entries=(),
            quiet_after_restart=False,
            burst=BurstWindow(WINDOW),
            now=NOW,
        )


def test_home_rules_fixture_matches_requirement():
    assert HOME_RULES.detection == REGULAR
    assert HOME_RULES.detection_asleep_or_night == CRITICAL
    assert HOME_RULES.sound == SILENT
