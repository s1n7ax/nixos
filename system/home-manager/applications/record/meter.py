"""The mic level bar shown during preflight, beside the resolved desktop source.

A second reader of the same source the take holds — PipeWire allows many readers, and
a capture and a live meter were measured reading the fifine at once without complaint.
It runs until Enter, which is when the human has finished looking at it.
"""

from __future__ import annotations

import re

FLOOR = -91.0
"""What digital silence reports, where `-inf` would otherwise break the arithmetic."""

CEILING = 0.0
WIDTH = 30

_PEAK = re.compile(r"lavfi\.astats\.Overall\.Peak_level=(?P<level>\S+)")


def parse_peak(line: str) -> float | None:
    """The peak level out of one `ametadata=print` line, or None if it is not one."""
    match = _PEAK.search(line)
    if not match:
        return None
    raw = match.group("level")
    if "inf" in raw:
        return FLOOR
    try:
        return float(raw)
    except ValueError:
        return None


def bar(level: float) -> str:
    """A fixed-width bar. -60 dB is empty, 0 dB is full."""
    span = CEILING - -60.0
    filled = round((level - -60.0) / span * WIDTH)
    filled = min(WIDTH, max(0, filled))
    return "#" * filled + " " * (WIDTH - filled)


def line(level: float, desktop: str) -> str:
    """One terminal line: how loud the mic is, and what desktop audio resolved to."""
    return f"\r  mic {level:7.1f} dB |{bar(level)}|  desktop: {desktop}"
