"""What the AC should do: which spots get air, where it points and how hard it blows.

Pure: no Home Assistant. The integration feeds it the clock, the spot switches and the
AC's reported state, and carries out what it returns. Times are local and timezone-aware.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time, timedelta

MY_DESK = "my_desk"
BED = "bed"
WIFE_DESK = "wife_desk"
SPOTS = (MY_DESK, BED, WIFE_DESK)
# Where the air goes for a spot; the bed has its own aim while s1n7ax sleeps, away from
# the pillows at its right end.
BED_SLEEP = "bed_sleep"
AIMS = (MY_DESK, BED, BED_SLEEP, WIFE_DESK)
VERTICAL = ("V0", "V1", "V2", "V3", "V4", "V5")
HORIZONTAL = ("H0", "H1", "H2", "H3", "H4", "H5")
DEFAULT_AIMS = {
    MY_DESK: ("V2", "H5"),
    BED: ("V5", "H2"),
    BED_SLEEP: ("V5", "H3"),
    WIFE_DESK: ("V4", "H5"),
}

# The day, every day: from each moment on, these spots get air.
STEPS = (
    (time(8), frozenset({BED, WIFE_DESK})),
    (time(9), frozenset(SPOTS)),
    (time(10), frozenset({BED, WIFE_DESK})),
    (time(18), frozenset(SPOTS)),
    (time(22), frozenset({BED, MY_DESK})),
)
NIGHT = time(22)
SLEEP_SPOTS = frozenset({BED})
# A sleep reading before this is a nap, or the phone lying still on the desk.
SLEEP_SIGNAL_FROM = time(23)
SLEEP_FALLBACK = time(1, 30)
SLEEP_CONFIDENCE = 90
GENTLE_AFTER = timedelta(hours=3)

TEMPERATURE = 29
# Late in sleep the room gets humid; a lower target makes the AC cool and dry it.
GENTLE_TEMPERATURE = 27
FAN_HIGH = "high"
FAN_MEDIUM = "medium"
HOLD = timedelta(hours=1)
DWELL = timedelta(minutes=2)
# The AC reports a command back through its cloud, a few seconds later and one setting at
# a time. Before RESEND a command not reported yet is not sent again; within REPORT_WINDOW
# a report made only of values from before or after a recent command is that command
# arriving. Turning on or coming back online also reports for a while, one setting at a time.
RESEND = timedelta(seconds=45)
REPORT_WINDOW = timedelta(minutes=2)
# The climate services a person steers the AC with; one called from HA by a person is a manual
# change however the AC reports it back.
STEERING = ("set_fan_mode", "set_swing_mode", "set_swing_horizontal_mode")


# (fan, vertical, horizontal), as the AC reports it.
Setting = tuple[str, str, str]
# (when, what the AC reported then, what was sent). A None setting stands for any value:
# the AC turning on or coming back online, whose reports can say anything for a while.
Command = tuple[datetime, Setting | None, Setting | None]


@dataclass(frozen=True)
class Step:
    key: str
    spots: frozenset[str]
    asleep_since: datetime | None


@dataclass(frozen=True)
class Plan:
    """Where the air goes now. `targets` are the aims it sweeps across, in order."""

    targets: tuple[str, ...]
    target: str
    vertical: str
    horizontal: str
    fan: str

    @property
    def setting(self) -> Setting:
        return (self.fan, self.vertical, self.horizontal)


def _at(day: datetime, moment: time) -> datetime:
    return day.replace(hour=moment.hour, minute=moment.minute, second=0, microsecond=0)


def last_moment(now: datetime) -> tuple[datetime, frozenset[str]]:
    """The latest schedule moment at or before `now`, and its spots."""
    for day in (now, now - timedelta(days=1)):
        for moment, spots in reversed(STEPS):
            at = _at(day, moment)
            if at <= now:
                return at, spots
    raise AssertionError("unreachable: every day has a moment")


def asleep_since(
    now: datetime, since: datetime | None, confidence: float | None
) -> datetime | None:
    """When s1n7ax fell asleep tonight, or None while awake.

    Only after the 22:00 step: the phone's sleep confidence from 23:00, or 01:30 when the
    phone has said nothing by then. Ends at 08:00, when the next step starts.
    """
    moment, _ = last_moment(now)
    if moment.time() != NIGHT:
        return None
    if since is not None and since >= moment:
        return since
    if confidence is not None and confidence >= SLEEP_CONFIDENCE:
        if now >= _at(moment, SLEEP_SIGNAL_FROM):
            return now
    fallback = _at(moment + timedelta(days=1), SLEEP_FALLBACK)
    if now >= fallback:
        return fallback
    return None


def current_step(now: datetime, since: datetime | None, away: bool = False) -> Step:
    """The step in force: the last schedule moment, or sleep once it started after it.

    While s1n7ax is away, their desk gets no air.
    """
    moment, spots = last_moment(now)
    if since is not None and since >= moment:
        return Step(f"sleep {since.isoformat()}", SLEEP_SPOTS, since)
    return Step(moment.isoformat(), spots - {MY_DESK} if away else spots, None)


def gentle(now: datetime, since: datetime | None) -> bool:
    """Whether s1n7ax is GENTLE_AFTER into sleep: the fan slows and the target drops."""
    return since is not None and now >= since + GENTLE_AFTER


def temperature(now: datetime, since: datetime | None) -> int:
    """The AC's target temperature for this moment."""
    return GENTLE_TEMPERATURE if gentle(now, since) else TEMPERATURE


def plan(
    now: datetime,
    spots: frozenset[str] | set[str],
    aims: dict[str, tuple[str, str]],
    since: datetime | None,
) -> Plan | None:
    """The fan and the aim for this moment, or None when no spot wants air.

    With several spots the aim moves to the next one every DWELL, in a fixed order.
    """
    asleep = since is not None
    targets = tuple(BED_SLEEP if s == BED and asleep else s for s in SPOTS if s in spots)
    if not targets:
        return None
    target = targets[int(now.timestamp() // DWELL.total_seconds()) % len(targets)]
    vertical, horizontal = aims.get(target, DEFAULT_AIMS[target])
    fan = FAN_MEDIUM if gentle(now, since) else FAN_HIGH
    return Plan(targets, target, vertical, horizontal, fan)


def is_manual(
    before: Setting | None, after: Setting | None, commands: list[Command], now: datetime
) -> bool:
    """Whether a reported change of (fan, vertical, horizontal) came from someone's hand.

    `None` means the AC was off or unreachable: coming back is not a change. A hand that
    sets a value a command of the last REPORT_WINDOW also had is missed.
    """
    if before is None or after is None or after == before:
        return False
    if commands and after == commands[-1][2]:
        return False
    recent = [(old, new) for at, old, new in commands if now - at < REPORT_WINDOW]
    if any(old is None or new is None for old, new in recent):
        return False
    return any(all(a not in (old[i], new[i]) for old, new in recent) for i, a in enumerate(after))


def person_steers(call: dict, user_id: str | None, climate: str) -> bool:
    """Whether a service call (a `call_service` event's data) is a person steering `climate`."""
    if user_id is None or call.get("domain") != "climate" or call.get("service") not in STEERING:
        return False
    targets = call.get("service_data", {}).get("entity_id", [])
    return climate in ([targets] if isinstance(targets, str) else targets)
