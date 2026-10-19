"""The requirement's mode table, with made-up entity names."""

from __future__ import annotations

from core.policy import CRITICAL, NONE, REGULAR, REVIEW_ONLY, SILENT, HomeRules, Mode

ALL_AWAY = Mode(
    name="All away",
    entity="input_boolean.mode_c",
    detection=CRITICAL,
    sound=REGULAR,
    door_top=CRITICAL,
    door_other=CRITICAL,
    motion_top=CRITICAL,
    motion_other=SILENT,
)
WE_AWAY = Mode(
    name="We're away",
    entity="input_boolean.mode_b",
    detection=CRITICAL,
    sound=REGULAR,
    door_top=CRITICAL,
    door_other=NONE,
    motion_top=CRITICAL,
    motion_other=NONE,
)
I_AWAY = Mode(
    name="I'm away",
    entity="input_boolean.mode_a",
    detection=CRITICAL,
    sound=REGULAR,
    door_top=NONE,
    door_other=NONE,
    motion_top=NONE,
    motion_other=NONE,
)
LADDER = (ALL_AWAY, WE_AWAY, I_AWAY)
HOME = HomeRules(detection=REGULAR, detection_asleep_or_night=CRITICAL, sound=REVIEW_ONLY)
