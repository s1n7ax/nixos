from __future__ import annotations

import json

from core.pushes import DAY_SECONDS, RING_RESERVE, PushBudget, seeded, utc_day

REPEAT = 600.0
LIMIT = 450
# Noon UTC, so a repeat window stays inside one day.
NOW = 20_000 * DAY_SECONDS + DAY_SECONDS / 2
MIDNIGHT = 20_001 * DAY_SECONDS


def test_first_push_is_not_recent():
    assert not PushBudget(REPEAT, LIMIT).pushed_recently("person", "cam_a", NOW)


def test_window_per_type_and_camera():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", NOW)
    assert pushes.pushed_recently("person", "cam_a", NOW)
    assert pushes.pushed_recently("person", "cam_a", NOW + REPEAT - 1)
    assert not pushes.pushed_recently("person", "cam_a", NOW + REPEAT)
    assert not pushes.pushed_recently("person", "cam_b", NOW + 1)
    assert not pushes.pushed_recently("car", "cam_a", NOW + 1)


def test_record_restarts_the_window():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", NOW)
    pushes.record("person", "cam_a", NOW + REPEAT + 5)
    assert pushes.pushed_recently("person", "cam_a", NOW + REPEAT + 10)


def test_clock_going_back_is_not_recent():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", NOW)
    assert not pushes.pushed_recently("person", "cam_a", NOW - 100)


def test_no_repeat_window():
    pushes = PushBudget(0, LIMIT)
    pushes.record("person", "cam_a", NOW)
    assert not pushes.pushed_recently("person", "cam_a", NOW)


def test_a_sensor_counts_without_a_repeat_window():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("door", None, NOW)
    assert pushes.sent_today(NOW) == 1
    assert not pushes.pushed_recently("door", None, NOW + 1)
    assert pushes.as_dict()["last"] == {}
    pushes.forget("door", None, NOW)
    assert pushes.sent_today(NOW) == 0


def test_counts_the_pushes_of_the_utc_day():
    pushes = PushBudget(REPEAT, LIMIT)
    assert pushes.sent_today(NOW) == 0
    pushes.record("person", "cam_a", NOW)
    pushes.record("bark", "cam_b", MIDNIGHT - 1)
    assert pushes.sent_today(MIDNIGHT - 1) == 2
    assert pushes.sent_today(MIDNIGHT) == 0
    pushes.record("person", "cam_a", MIDNIGHT)
    assert pushes.sent_today(MIDNIGHT + 1) == 1


def test_repeat_window_runs_across_midnight():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", MIDNIGHT - 1)
    assert pushes.pushed_recently("person", "cam_a", MIDNIGHT + 1)


def test_only_a_ring_uses_the_reserve():
    pushes = PushBudget(REPEAT, LIMIT, {"day": utc_day(NOW), "sent": LIMIT - RING_RESERVE - 1})
    assert not pushes.spent(NOW, ring=False)
    pushes.record("person", "cam_a", NOW)
    assert pushes.spent(NOW, ring=False)
    assert not pushes.spent(NOW, ring=True)


def test_limit_stops_rings():
    pushes = PushBudget(REPEAT, LIMIT, {"day": utc_day(NOW), "sent": LIMIT - 1})
    assert not pushes.spent(NOW, ring=True)
    pushes.record("person", "cam_a", NOW)
    assert pushes.spent(NOW, ring=True)
    assert not pushes.spent(MIDNIGHT, ring=False)


def test_limit_below_the_reserve_only_rings():
    pushes = PushBudget(REPEAT, RING_RESERVE - 1)
    assert pushes.spent(NOW, ring=False)
    assert not pushes.spent(NOW, ring=True)


def test_saved_count_of_another_day_does_not_count():
    pushes = PushBudget(REPEAT, LIMIT, {"day": utc_day(NOW) - 1, "sent": LIMIT})
    assert pushes.sent_today(NOW) == 0
    assert not pushes.spent(NOW, ring=False)


def test_seeded_from_the_log():
    day = utc_day(NOW)
    assert seeded(day, 0, LIMIT) == {"day": day, "sent": 0}
    assert PushBudget(REPEAT, LIMIT, seeded(day, 123, LIMIT)).sent_today(NOW) == 123


def test_seeded_count_leaves_the_rings_their_reserve():
    pushes = PushBudget(REPEAT, LIMIT, seeded(utc_day(NOW), 1329, LIMIT))
    assert pushes.sent_today(NOW) == LIMIT - RING_RESERVE
    assert pushes.spent(NOW, ring=False)
    assert not pushes.spent(NOW, ring=True)
    assert seeded(utc_day(NOW), 5, RING_RESERVE - 1)["sent"] == 0


def test_round_trip():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", NOW)
    pushes.record("bark", "cam_b", NOW + 1)
    again = PushBudget(REPEAT, LIMIT, json.loads(json.dumps(pushes.as_dict())))
    assert again.sent_today(NOW + 2) == 2
    assert again.pushed_recently("person", "cam_a", NOW + 2)
    assert again.pushed_recently("bark", "cam_b", NOW + 2)
    assert again.as_dict() == pushes.as_dict()


def test_forget_undoes_a_push_that_never_went_out():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", NOW)
    pushes.forget("person", "cam_a", NOW)
    assert pushes.sent_today(NOW) == 0
    assert not pushes.pushed_recently("person", "cam_a", NOW + 1)


def test_forget_keeps_a_newer_push():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", NOW)
    pushes.record("person", "cam_a", NOW + REPEAT)
    pushes.forget("person", "cam_a", NOW)
    assert pushes.sent_today(NOW + REPEAT) == 1
    assert pushes.pushed_recently("person", "cam_a", NOW + REPEAT + 1)


def test_forget_leaves_the_next_day_alone():
    pushes = PushBudget(REPEAT, LIMIT)
    pushes.record("person", "cam_a", MIDNIGHT - 1)
    pushes.record("car", "cam_a", MIDNIGHT)
    pushes.forget("person", "cam_a", MIDNIGHT - 1)
    assert pushes.sent_today(MIDNIGHT) == 1
