"""Where the air goes for each spot: a vertical and a horizontal louver position."""

from __future__ import annotations

from homeassistant.components.select import SelectEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType

from . import DOMAIN, AirZones
from .entity import NAMES, AirZonesEntity
from .zones import AIMS, HORIZONTAL, VERTICAL

AXES = (("vertical", "Vertical", VERTICAL), ("horizontal", "Horizontal", HORIZONTAL))


async def async_setup_platform(
    hass: HomeAssistant,
    config: ConfigType,
    async_add_entities: AddEntitiesCallback,
    discovery_info: DiscoveryInfoType | None = None,
) -> None:
    controller = hass.data[DOMAIN]
    async_add_entities(
        AimSelect(controller, aim, axis) for aim in AIMS for axis in range(len(AXES))
    )


class AimSelect(AirZonesEntity, SelectEntity):
    platform_name = "select"
    _attr_entity_category = EntityCategory.CONFIG
    _attr_icon = "mdi:air-filter"

    def __init__(self, controller: AirZones, aim: str, axis: int) -> None:
        key, label, options = AXES[axis]
        super().__init__(controller, f"{aim}_{key}", f"{NAMES[aim]} {label.lower()}")
        self.aim = aim
        self.axis = axis
        self._attr_options = list(options)

    @property
    def current_option(self) -> str:
        return self.controller.aims[self.aim][self.axis]

    async def async_select_option(self, option: str) -> None:
        await self.controller.async_set_aim(self.aim, self.axis, option)
