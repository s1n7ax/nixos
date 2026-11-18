"""A switch per spot, and one for the whole automation."""

from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType

from . import DOMAIN, AirZones
from .entity import NAMES, AirZonesEntity
from .zones import SPOTS


async def async_setup_platform(
    hass: HomeAssistant,
    config: ConfigType,
    async_add_entities: AddEntitiesCallback,
    discovery_info: DiscoveryInfoType | None = None,
) -> None:
    controller = hass.data[DOMAIN]
    async_add_entities(
        [AutomationSwitch(controller), *(SpotSwitch(controller, spot) for spot in SPOTS)]
    )


class AutomationSwitch(AirZonesEntity, SwitchEntity):
    platform_name = "switch"
    _attr_icon = "mdi:robot"

    def __init__(self, controller: AirZones) -> None:
        super().__init__(controller, "automation", "automation")

    @property
    def is_on(self) -> bool:
        return self.controller.enabled

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.controller.async_set_enabled(True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.controller.async_set_enabled(False)


class SpotSwitch(AirZonesEntity, SwitchEntity):
    platform_name = "switch"
    _attr_icon = "mdi:account"

    def __init__(self, controller: AirZones, spot: str) -> None:
        super().__init__(controller, spot, NAMES[spot])
        self.spot = spot

    @property
    def is_on(self) -> bool:
        return self.spot in self.controller.spots

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.controller.async_set_spot(self.spot, True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.controller.async_set_spot(self.spot, False)
