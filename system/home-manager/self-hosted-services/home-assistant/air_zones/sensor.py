"""What the automation is doing, for the dashboard."""

from __future__ import annotations

from typing import Any

from homeassistant.components.sensor import SensorDeviceClass, SensorEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType

from . import DOMAIN, AirZones
from .entity import AirZonesEntity


async def async_setup_platform(
    hass: HomeAssistant,
    config: ConfigType,
    async_add_entities: AddEntitiesCallback,
    discovery_info: DiscoveryInfoType | None = None,
) -> None:
    async_add_entities([StatusSensor(hass.data[DOMAIN])])


class StatusSensor(AirZonesEntity, SensorEntity):
    platform_name = "sensor"
    _attr_icon = "mdi:air-conditioner"
    _attr_device_class = SensorDeviceClass.ENUM
    _attr_options = ["ac_off", "paused", "holding", "idle", "aimed", "sweeping"]

    def __init__(self, controller: AirZones) -> None:
        super().__init__(controller, "status", "status")

    @property
    def native_value(self) -> str:
        return self.controller.status()

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        c = self.controller
        plan = c.plan
        return {
            "targets": list(plan.targets) if plan else [],
            "target": plan.target if plan else None,
            "fan": plan.fan if plan else None,
            "asleep_since": c.asleep_since and c.asleep_since.isoformat(),
            "hold_until": c.hold_until and c.hold_until.isoformat(),
        }
