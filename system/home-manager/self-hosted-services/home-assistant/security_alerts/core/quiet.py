"""Pause, Do-not-disturb and Snooze entries: what they match and which one wins."""

from __future__ import annotations

from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from typing import Any

from .policy import CRITICAL, EVENT_KINDS, REGULAR, SENSOR_KINDS, SILENT, Mode

PAUSE = "pause"
DND = "dnd"
SNOOZE = "snooze"
QUIET_KINDS = (PAUSE, DND, SNOOZE)

# The quietest effect wins when several entries match one event.
_STRENGTH = {PAUSE: 3, SNOOZE: 2, DND: 1}

# The levels each kind changes, as decide applies it: Pause sends nothing, Snooze
# sends silent and Do-not-disturb turns critical into regular.
_CHANGES = {PAUSE: (SILENT, REGULAR, CRITICAL), SNOOZE: (REGULAR, CRITICAL), DND: (CRITICAL,)}


@dataclass(frozen=True)
class QuietEntry:
    """A time-limited Pause, Do-not-disturb or Snooze for some types.

    `cameras` empty means every camera. Door and motion events have no camera,
    so they only match entries with no cameras.
    """

    id: str
    kind: str
    types: tuple[str, ...]
    cameras: tuple[str, ...]
    created: float
    ends_at: float

    def is_running(self, now: float) -> bool:
        return now < self.ends_at

    def matches(self, event_type: str, camera: str | None) -> bool:
        if event_type not in self.types:
            return False
        if not self.cameras:
            return True
        return camera is not None and camera in self.cameras

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "types": list(self.types),
            "cameras": list(self.cameras),
            "created": self.created,
            "ends_at": self.ends_at,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> QuietEntry:
        return cls(
            id=str(data["id"]),
            kind=str(data["kind"]),
            types=tuple(data["types"]),
            cameras=tuple(data.get("cameras") or ()),
            created=float(data["created"]),
            ends_at=float(data["ends_at"]),
        )


def new_entries(
    kind: str,
    types: Iterable[str],
    cameras: Iterable[str],
    hours: float,
    now: float,
    make_id: Callable[[], str],
) -> list[QuietEntry]:
    """Build the entries for one request.

    A request limited to cameras that also names door or motion is split: the
    sensor types get their own entry with no cameras, so they still match.
    """
    if kind not in QUIET_KINDS:
        raise ValueError(f"Unknown quiet kind: {kind}")
    if hours <= 0:
        raise ValueError("A quiet entry needs a positive duration")
    types = tuple(dict.fromkeys(types))
    cameras = tuple(dict.fromkeys(cameras))
    if not types:
        raise ValueError("A quiet entry needs at least one type")
    ends_at = now + hours * 3600

    def entry(entry_types: Sequence[str], entry_cameras: tuple[str, ...]) -> QuietEntry:
        return QuietEntry(make_id(), kind, tuple(entry_types), entry_cameras, now, ends_at)

    if not cameras:
        return [entry(types, ())]
    camera_types = [t for t in types if t not in SENSOR_KINDS]
    sensor_types = [t for t in types if t in SENSOR_KINDS]
    entries = []
    if camera_types:
        entries.append(entry(camera_types, cameras))
    if sensor_types:
        entries.append(entry(sensor_types, ()))
    return entries


def running(entries: Iterable[QuietEntry], now: float) -> list[QuietEntry]:
    return [e for e in entries if e.is_running(now)]


def next_expiry(entries: Iterable[QuietEntry], now: float) -> float | None:
    """Return the earliest end of a running entry, or None."""
    ends = [e.ends_at for e in entries if e.is_running(now)]
    return min(ends, default=None)


def strongest(
    entries: Iterable[QuietEntry], event_type: str, camera: str | None, now: float
) -> QuietEntry | None:
    """Return the running entry that quiets this event the most, or None."""
    best: QuietEntry | None = None
    for entry in entries:
        if not entry.is_running(now) or not entry.matches(event_type, camera):
            continue
        if best is None or _STRENGTH[entry.kind] > _STRENGTH[best.kind]:
            best = entry
    return best


def changed_kinds(mode: Mode) -> dict[str, tuple[str, ...]]:
    """For each quiet kind, the event kinds (in EVENT_KINDS order) it changes in `mode`.

    A kind is changed when at least one of its levels in the mode is, so door counts
    when only its top-floor level is.
    """
    return {
        quiet_kind: tuple(
            kind for kind in EVENT_KINDS if any(level in levels for level in mode.levels(kind))
        )
        for quiet_kind, levels in _CHANGES.items()
    }
