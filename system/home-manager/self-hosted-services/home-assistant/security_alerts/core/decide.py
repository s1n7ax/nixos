"""Turn an event's base level into one delivery.

Order: base level, Pause, Snooze, Do-not-disturb, quiet after restart, burst.
Each step can only make the delivery quieter, so the quietest wins.

A base of review_only is logged for the review view and never sent, so it skips
every step after the base: no quieting changes it and it never rings.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass

from .burst import BurstWindow
from .policy import CRITICAL, LEVELS, NONE, REGULAR, REVIEW_ONLY, SILENT
from .quiet import DND, PAUSE, SNOOZE, QuietEntry, strongest

PAUSED = "paused"
POPUP = "popup"
DELIVERIES = (NONE, REVIEW_ONLY, PAUSED, SILENT, REGULAR, POPUP, CRITICAL)

_QUIET_NAMES = {PAUSE: "Pause", SNOOZE: "Snooze", DND: "Do-not-disturb"}


@dataclass(frozen=True)
class Decision:
    """How one event is delivered.

    `delivery` is none (not an alert at all), review_only (logged for the review
    view, not sent), paused (logged, not sent, marked paused), silent, regular,
    popup (a critical burst repeat that pops up without ringing) or critical.
    `rings` says the burst window restarts for this type.
    """

    delivery: str
    base: str
    reason: str
    quiet_id: str | None = None

    @property
    def rings(self) -> bool:
        return self.delivery == CRITICAL

    @property
    def is_alert(self) -> bool:
        return self.delivery != NONE

    @property
    def is_sent(self) -> bool:
        return self.delivery not in (NONE, REVIEW_ONLY, PAUSED)


def decide(
    *,
    base: str,
    mode_name: str,
    event_type: str,
    camera: str | None,
    quiet_entries: Iterable[QuietEntry],
    quiet_after_restart: bool,
    burst: BurstWindow,
    now: float,
) -> Decision:
    """Return the delivery for one event. Does not record the ring."""
    if base not in LEVELS:
        raise ValueError(f"Unknown level: {base}")
    steps = [f"{mode_name}: {base}"]
    if base in (NONE, REVIEW_ONLY):
        # Nothing is sent, so no quiet entry or burst window applies.
        return Decision(base, base, "; ".join(steps))

    entry = strongest(quiet_entries, event_type, camera, now)
    quiet_id = entry.id if entry else None
    delivery = base
    if entry is not None and entry.kind == PAUSE:
        steps.append(f"{_QUIET_NAMES[PAUSE]}: paused")
        return Decision(PAUSED, base, "; ".join(steps), quiet_id)
    if entry is not None and entry.kind == SNOOZE:
        delivery = SILENT
        steps.append(f"{_QUIET_NAMES[SNOOZE]}: silent")
    elif entry is not None and entry.kind == DND and delivery == CRITICAL:
        delivery = REGULAR
        steps.append(f"{_QUIET_NAMES[DND]}: regular")

    if quiet_after_restart and delivery != SILENT:
        delivery = SILENT
        steps.append("quiet after restart: silent")

    if delivery == CRITICAL and burst.rang_recently(event_type, now):
        delivery = POPUP
        steps.append("rang in the last burst window: popup")

    return Decision(delivery, base, "; ".join(steps), quiet_id)
