"""Air zones: aims the AC at whoever needs cooling, through the day.

Set up from an `air_zones:` line in configuration.yaml. It adds a switch per spot (my
desk, bed, wife's desk), an automation switch, a vertical and a horizontal aim select per
spot and a status sensor. The schedule, the sleep rules and the sweep live in `zones.py`.
While s1n7ax is away from home, their desk is left out.

It only steers the AC while the AC is on, and never turns it on. A fan or direction
change made by hand (HA, the MirAIe app or the remote) is left alone for an hour. One made
by a person in HA is known from the service call; others from how the AC reports them.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

import voluptuous as vol
from homeassistant.const import (
    EVENT_CALL_SERVICE,
    STATE_HOME,
    STATE_UNAVAILABLE,
    STATE_UNKNOWN,
    Platform,
)
from homeassistant.core import Event, EventStateChangedData, HomeAssistant, State, callback
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.discovery import async_load_platform
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import async_track_state_change_event, async_track_time_interval
from homeassistant.helpers.start import async_at_started
from homeassistant.helpers.storage import Store
from homeassistant.helpers.typing import ConfigType
from homeassistant.util import dt as dt_util

from . import zones

_LOGGER = logging.getLogger(__name__)

DOMAIN = "air_zones"
SIGNAL = f"{DOMAIN}_update"
CONF_CLIMATE = "climate"
CONF_SLEEP_SENSOR = "sleep_sensor"
CONF_PERSON = "person"
INTERVAL = timedelta(seconds=15)
PLATFORMS = (Platform.SWITCH, Platform.SELECT, Platform.SENSOR)
OFF_STATES = ("off", STATE_UNAVAILABLE, STATE_UNKNOWN)

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Optional(
                    CONF_CLIMATE, default="climate.panasonic_ac_panasonic_ac"
                ): cv.entity_id,
                vol.Optional(
                    CONF_SLEEP_SENSOR, default="sensor.pixel_9_pro_xl_sleep_confidence"
                ): cv.entity_id,
                vol.Optional(CONF_PERSON, default="person.s1n7ax"): cv.entity_id,
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    if DOMAIN not in config:
        return True
    controller = AirZones(hass, config[DOMAIN])
    await controller.async_load()
    hass.data[DOMAIN] = controller
    for platform in PLATFORMS:
        hass.async_create_task(async_load_platform(hass, platform, DOMAIN, {}, config))
    async_at_started(hass, controller.start)
    return True


def _is_off(state: State | None) -> bool:
    """Off or unreachable."""
    return state is None or state.state in OFF_STATES


def _setting(state: State | None) -> zones.Setting | None:
    """The AC's (fan, vertical, horizontal), or None while it is off or unreachable."""
    if _is_off(state):
        return None
    a = state.attributes
    return (a.get("fan_mode"), a.get("swing_mode"), a.get("swing_horizontal_mode"))


def _time(value: str | None) -> datetime | None:
    return dt_util.parse_datetime(value) if value else None


class AirZones:
    """Holds the spot switches and aims, and carries out `zones.plan` on the AC."""

    def __init__(self, hass: HomeAssistant, conf: ConfigType) -> None:
        self.hass = hass
        self.climate = conf[CONF_CLIMATE]
        self.sleep_sensor = conf[CONF_SLEEP_SENSOR]
        self.person = conf[CONF_PERSON]
        self.store = Store(hass, 1, DOMAIN)
        self.enabled = True
        self.spots: set[str] = set()
        self.aims = dict(zones.DEFAULT_AIMS)
        self.asleep_since: datetime | None = None
        self.away = False
        self.last_step: str | None = None
        self.hold_until: datetime | None = None
        # The target temperature is set once per step and when it changes, when the AC is on.
        self.temperature = zones.TEMPERATURE
        self.temperature_due = False
        # What was last sent to the AC, and when; in memory only.
        self.expected: zones.Setting | None = None
        self.last_command: datetime | None = None
        self.commands: list[zones.Command] = []
        self.plan: zones.Plan | None = None

    async def async_load(self) -> None:
        data = await self.store.async_load() or {}
        self.enabled = data.get("enabled", True)
        self.spots = set(data.get("spots", [])) & set(zones.SPOTS)
        self.aims.update({k: tuple(v) for k, v in data.get("aims", {}).items() if k in zones.AIMS})
        self.asleep_since = _time(data.get("asleep_since"))
        self.away = data.get("away", False)
        self.last_step = data.get("last_step")
        self.hold_until = _time(data.get("hold_until"))
        self.temperature = data.get("temperature", zones.TEMPERATURE)
        self.temperature_due = data.get("temperature_due", False)

    @callback
    def _save(self) -> None:
        self.store.async_delay_save(
            lambda: {
                "enabled": self.enabled,
                "spots": sorted(self.spots),
                "aims": {k: list(v) for k, v in self.aims.items()},
                "asleep_since": self.asleep_since and self.asleep_since.isoformat(),
                "away": self.away,
                "last_step": self.last_step,
                "hold_until": self.hold_until and self.hold_until.isoformat(),
                "temperature": self.temperature,
                "temperature_due": self.temperature_due,
            },
            1,
        )

    @callback
    def start(self, _hass: HomeAssistant) -> None:
        async_track_time_interval(self.hass, self._interval, INTERVAL)
        async_track_state_change_event(self.hass, [self.climate], self._climate_changed)
        self.hass.bus.async_listen(EVENT_CALL_SERVICE, self._service_called)
        self.hass.async_create_task(self.async_update())

    async def _interval(self, _now: datetime) -> None:
        await self.async_update()

    @callback
    def _climate_changed(self, event: Event[EventStateChangedData]) -> None:
        before = _setting(event.data["old_state"])
        after = _setting(event.data["new_state"])
        now = dt_util.now()
        self.commands = [c for c in self.commands if now - c[0] < zones.REPORT_WINDOW]
        if zones.is_manual(before, after, self.commands, now):
            self._hold(now, f"Manual AC change to {after}")
        elif before is None and after is not None:
            # Turned on or back online: aim it now, not at the next interval.
            self.expected = None
            self.commands.append((now, None, None))
            self.hass.async_create_task(self.async_update())
        # The status follows the AC at once, e.g. "ac_off", not at the next interval.
        async_dispatcher_send(self.hass, SIGNAL)

    @callback
    def _service_called(self, event: Event) -> None:
        """A person steering the AC from HA holds it, even while its reports can't tell."""
        if not zones.person_steers(event.data, event.context.user_id, self.climate):
            return
        self._hold(dt_util.now(), f"climate.{event.data['service']} by a person")
        async_dispatcher_send(self.hass, SIGNAL)

    @callback
    def _hold(self, now: datetime, why: str) -> None:
        _LOGGER.info("%s; holding until %s", why, now + zones.HOLD)
        self.hold_until = now + zones.HOLD
        self._save()

    async def async_set_spot(self, spot: str, on: bool) -> None:
        (self.spots.add if on else self.spots.discard)(spot)
        await self._changed_by_user()

    async def async_set_enabled(self, on: bool) -> None:
        self.enabled = on
        await self._changed_by_user()

    async def async_set_aim(self, aim: str, axis: int, mode: str) -> None:
        aim_now = list(self.aims[aim])
        aim_now[axis] = mode
        self.aims[aim] = tuple(aim_now)
        # Tuning where a spot's air goes is not steering the AC: a hold stays.
        self._save()
        await self.async_update()

    async def _changed_by_user(self) -> None:
        """A tap on the dashboard: act on it now, ending any hold."""
        self.hold_until = None
        self._save()
        await self.async_update()

    def _sleep_confidence(self) -> float | None:
        state = self.hass.states.get(self.sleep_sensor)
        try:
            return float(state.state) if state else None
        except ValueError:
            return None

    def _away(self) -> bool:
        """Whether s1n7ax is away; the last known answer while their person is unknown."""
        state = self.hass.states.get(self.person)
        if _is_off(state):
            return self.away
        return state.state != STATE_HOME

    async def async_update(self) -> None:
        now = dt_util.now()
        self.asleep_since = zones.asleep_since(now, self.asleep_since, self._sleep_confidence())
        away = self._away()
        step = zones.current_step(now, self.asleep_since, away)
        if step.key != self.last_step:
            _LOGGER.info("Step %s: %s", step.key, sorted(step.spots))
            self.last_step = step.key
            self.spots = set(step.spots)
            self.temperature_due = True
            self._save()
        elif away != self.away:
            # Leaving or coming home mid-step moves only the desk; other spots stay as set.
            _LOGGER.info("s1n7ax %s", "left" if away else "came home")
            if away:
                self.spots.discard(zones.MY_DESK)
            elif zones.MY_DESK in zones.current_step(now, self.asleep_since).spots:
                self.spots.add(zones.MY_DESK)
        if away != self.away:
            self.away = away
            self._save()
        temperature = zones.temperature(now, self.asleep_since)
        if temperature != self.temperature:
            _LOGGER.info("Target temperature %s °C", temperature)
            self.temperature = temperature
            self.temperature_due = True
            self._save()
        self.plan = zones.plan(now, self.spots, self.aims, self.asleep_since)
        if self.hold_until is not None and now >= self.hold_until:
            self.hold_until = None
            self.expected = None
            self._save()
        try:
            await self._async_command(now)
        finally:
            async_dispatcher_send(self.hass, SIGNAL)

    async def _async_command(self, now: datetime) -> None:
        state = self.hass.states.get(self.climate)
        current = _setting(state)
        if not self.enabled or current is None:
            return
        target = {"entity_id": self.climate}
        if self.temperature_due:
            if state.attributes.get("temperature") == self.temperature or await self._call(
                "set_temperature", {**target, "temperature": self.temperature}
            ):
                self.temperature_due = False
                self._save()
        if self.hold_until is not None or self.plan is None:
            return
        wanted = self.plan.setting
        # Give the AC time to report the last command back before sending it again.
        if current == wanted or (
            wanted == self.expected
            and self.last_command is not None
            and now - self.last_command < zones.RESEND
        ):
            return
        self.expected = wanted
        self.last_command = now
        self.commands.append((now, current, wanted))
        calls = (
            ("set_fan_mode", "fan_mode"),
            ("set_swing_mode", "swing_mode"),
            ("set_swing_horizontal_mode", "swing_horizontal_mode"),
        )
        for (service, attr), now_set, value in zip(calls, current, wanted, strict=True):
            # A person may steer the AC while an earlier call waits on the cloud.
            if self.hold_until is not None:
                return
            if now_set != value:
                await self._call(service, {**target, attr: value})

    async def _call(self, service: str, data: dict) -> bool:
        try:
            await self.hass.services.async_call("climate", service, data, blocking=True)
        except Exception:  # The MirAIe cloud drops out often; the next interval retries.
            _LOGGER.warning("climate.%s %s failed", service, data, exc_info=True)
            return False
        return True

    def status(self) -> str:
        """One word for the status sensor."""
        if _is_off(self.hass.states.get(self.climate)):
            return "ac_off"
        if not self.enabled:
            return "paused"
        if self.hold_until is not None:
            return "holding"
        if self.plan is None:
            return "idle"
        return "sweeping" if len(self.plan.targets) > 1 else "aimed"
