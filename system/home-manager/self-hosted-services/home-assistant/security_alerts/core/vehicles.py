"""Parked vehicles: a car or bike Frigate first tracks while it is already still.

Our own vehicles park in view of a camera. When Frigate restarts, or loses and finds a
parked vehicle again, it tracks it as a new object that never moved. Arriving vehicles
are moving when their clip starts, so they still alert.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

VEHICLES = frozenset({"car", "motorcycle"})


def is_parked_vehicle(after: Mapping[str, Any]) -> bool:
    """Whether a Frigate event's `after` is a vehicle that was still when tracked."""
    return after.get("label") in VEHICLES and after.get("stationary") is True
