"""One critical ring per type per window."""

from __future__ import annotations

from collections.abc import Mapping


class BurstWindow:
    """The last critical ring per type."""

    def __init__(self, window_seconds: float, last_rings: Mapping[str, float] | None = None):
        self.window_seconds = window_seconds
        self._last_rings = dict(last_rings or {})

    def rang_recently(self, event_type: str, now: float) -> bool:
        last = self._last_rings.get(event_type)
        return last is not None and 0 <= now - last < self.window_seconds

    def record(self, event_type: str, now: float) -> None:
        """Restart the window for this type."""
        self._last_rings[event_type] = now

    def as_dict(self) -> dict[str, float]:
        return dict(self._last_rings)
