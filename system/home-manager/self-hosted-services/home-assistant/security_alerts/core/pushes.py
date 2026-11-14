"""Keep the phone's pushes under the Companion app's daily limit.

The app's push service delivers a fixed number of pushes a day to one phone and
drops the rest, rings included, until midnight UTC. Two rules keep the alerts
under it: a camera pushes each type once per repeat window unless it rings, and
the day's pushes stop at a limit whose last part is kept for rings.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

DAY_SECONDS = 24 * 60 * 60
# The last pushes of the day's limit are kept for rings.
RING_RESERVE = 80


def utc_day(now: float) -> int:
    """The UTC day of a timestamp, counted from the epoch."""
    return int(now // DAY_SECONDS)


def seeded(day: int, logged: int, daily_limit: int) -> dict[str, Any]:
    """A saved count for `day`, made from the pushes the alert log holds for it.

    The log also holds pushes the limit never counted (the phone took them over
    its own connection), so the count leaves the rings their reserve.
    """
    return {"day": day, "sent": min(logged, max(daily_limit - RING_RESERVE, 0))}


class PushBudget:
    """The pushes sent today (UTC) and the last push per type and camera.

    Door and motion sensors have no camera: their pushes count, without a repeat
    window.
    """

    def __init__(
        self, repeat_seconds: float, daily_limit: int, saved: Mapping[str, Any] | None = None
    ):
        saved = saved or {}
        self.repeat_seconds = repeat_seconds
        self.daily_limit = daily_limit
        self._day: int | None = saved.get("day")
        self._sent: int = saved.get("sent", 0)
        self._last: dict[str, dict[str, float]] = {
            event_type: dict(cameras) for event_type, cameras in saved.get("last", {}).items()
        }

    def sent_today(self, now: float) -> int:
        return self._sent if self._day == utc_day(now) else 0

    def pushed_recently(self, event_type: str, camera: str | None, now: float) -> bool:
        if camera is None:
            return False
        last = self._last.get(event_type, {}).get(camera)
        return last is not None and 0 <= now - last < self.repeat_seconds

    def spent(self, now: float, *, ring: bool) -> bool:
        """Whether today's pushes are used up; only a ring may use the reserve."""
        limit = self.daily_limit if ring else self.daily_limit - RING_RESERVE
        return self.sent_today(now) >= limit

    def record(self, event_type: str, camera: str | None, now: float) -> None:
        """Count a push and restart the repeat window for this type on this camera."""
        self._sent = self.sent_today(now) + 1
        self._day = utc_day(now)
        if camera is not None:
            self._last.setdefault(event_type, {})[camera] = now

    def forget(self, event_type: str, camera: str | None, at: float) -> None:
        """Undo the push recorded at `at` (it never went out)."""
        if self._day == utc_day(at) and self._sent > 0:
            self._sent -= 1
        cameras = self._last.get(event_type, {})
        if camera is not None and cameras.get(camera) == at:
            del cameras[camera]

    def as_dict(self) -> dict[str, Any]:
        return {
            "day": self._day,
            "sent": self._sent,
            "last": {event_type: dict(cameras) for event_type, cameras in self._last.items()},
        }
