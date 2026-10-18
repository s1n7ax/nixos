"""Which mode is on, and the level an event gets from it."""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import time

NONE = "none"
SILENT = "silent"
REGULAR = "regular"
CRITICAL = "critical"
LEVELS = (NONE, SILENT, REGULAR, CRITICAL)

DETECTION = "detection"
SOUND = "sound"
DOOR = "door"
MOTION = "motion"
EVENT_KINDS = (DETECTION, SOUND, DOOR, MOTION)
SENSOR_KINDS = (DOOR, MOTION)

HOME = "Home"


@dataclass(frozen=True)
class Mode:
    """One away mode: the switch that turns it on and a level per event."""

    name: str
    entity: str
    detection: str
    sound: str
    door_top: str
    door_other: str
    motion_top: str
    motion_other: str

    def level(self, kind: str, top_floor: bool) -> str:
        if kind == DETECTION:
            return self.detection
        if kind == SOUND:
            return self.sound
        if kind == DOOR:
            return self.door_top if top_floor else self.door_other
        if kind == MOTION:
            return self.motion_top if top_floor else self.motion_other
        raise ValueError(f"Unknown event kind: {kind}")


@dataclass(frozen=True)
class HomeRules:
    """Levels while no away mode is on. Door and motion sensors are not armed."""

    detection: str
    detection_asleep_or_night: str
    sound: str

    def level(self, kind: str, asleep: bool, night: bool) -> str:
        if kind == DETECTION:
            return self.detection_asleep_or_night if asleep or night else self.detection
        if kind == SOUND:
            return self.sound
        if kind in SENSOR_KINDS:
            return NONE
        raise ValueError(f"Unknown event kind: {kind}")


def active_mode(modes: Sequence[Mode], is_on: Callable[[str], bool]) -> Mode | None:
    """Return the highest mode that is on; `modes` is in ladder order, highest first."""
    for mode in modes:
        if is_on(mode.entity):
            return mode
    return None


def is_asleep(state: str | None, threshold: float) -> bool:
    """Read the phone's sleep confidence; anything that is not a number is awake."""
    try:
        return float(state) >= threshold  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return False


def is_night(now: time, start: time, end: time) -> bool:
    """Return whether `now` is in [start, end), wrapping past midnight."""
    if start == end:
        return False
    if start < end:
        return start <= now < end
    return now >= start or now < end


def base_level(
    kind: str,
    *,
    mode: Mode | None,
    home: HomeRules,
    top_floor: bool,
    asleep: bool,
    night: bool,
) -> str:
    """Return the level an event gets before any quieting."""
    if mode is None:
        return home.level(kind, asleep, night)
    return mode.level(kind, top_floor)
