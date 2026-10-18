"""`sensor.security_alerts_quiet`: the running Pause, Do-not-disturb and Snooze entries."""

from __future__ import annotations

from typing import Any

from homeassistant.components.sensor import SensorEntity
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType
from homeassistant.util import dt as dt_util

from .const import DOMAIN, SIGNAL_QUIET_UPDATED
from .core.quiet import PAUSE, QuietEntry
from .pipeline import SecurityAlerts


async def async_setup_platform(
    hass: HomeAssistant,
    config: ConfigType,
    async_add_entities: AddEntitiesCallback,
    discovery_info: DiscoveryInfoType | None = None,
) -> None:
    if discovery_info is None:
        return
    async_add_entities([QuietSensor(hass.data[DOMAIN])])


def _iso(timestamp: float) -> str:
    return dt_util.as_local(dt_util.utc_from_timestamp(timestamp)).isoformat()


def _attributes(entry: QuietEntry) -> dict[str, Any]:
    return {
        "id": entry.id,
        "kind": entry.kind,
        "types": list(entry.types),
        "cameras": list(entry.cameras),
        "created": _iso(entry.created),
        "ends_at": _iso(entry.ends_at),
    }


class QuietSensor(SensorEntity):
    _attr_name = "Security alerts quiet"
    _attr_unique_id = "security_alerts_quiet"
    _attr_icon = "mdi:bell-cancel"
    _attr_should_poll = False

    def __init__(self, alerts: SecurityAlerts) -> None:
        self._alerts = alerts

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(
            async_dispatcher_connect(self.hass, SIGNAL_QUIET_UPDATED, self._updated)
        )

    @callback
    def _updated(self) -> None:
        self.async_write_ha_state()

    @property
    def native_value(self) -> int:
        return len(self._alerts.running_quiet())

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        entries = sorted(self._alerts.running_quiet(), key=lambda e: e.ends_at)
        return {
            "entries": [_attributes(e) for e in entries],
            "pauses": [_attributes(e) for e in entries if e.kind == PAUSE],
        }
