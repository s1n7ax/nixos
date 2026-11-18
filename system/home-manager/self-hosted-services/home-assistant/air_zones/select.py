"""Where the air goes for each spot: a vertical and a horizontal louver position."""

from __future__ import annotations

from homeassistant.components.select import SelectEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import DOMAIN
from .entity import NAMES, AirZonesEntity
from .zones import AIMS, HORIZONTAL, VERTICAL

AXES = (("vertical", "Vertical", VERTICAL), ("horizontal", "Horizontal", HORIZONTAL))


async def async_setup_platform(
    hass: HomeAssistant, _config, add: AddEntitiesCallback, _info=None
) -> None:
    controller = hass.data[DOMAIN]
    add(AimSelect(controller, aim, axis) for aim in AIMS for axis in range(len(AXES)))


class AimSelect(AirZonesEntity, SelectEntity):
    _attr_entity_category = EntityCategory.CONFIG
    _attr_icon = "mdi:air-filter"

    def __init__(self, controller, aim: str, axis: int) -> None:
        key, label, options = AXES[axis]
        super().__init__(controller, f"{aim}_{key}")
        self.aim = aim
        self.axis = axis
        self._attr_name = f"{NAMES[aim]} {label.lower()}"
        self._attr_options = list(options)

    @property
    def current_option(self) -> str:
        return self.controller.aims[self.aim][self.axis]

    async def async_select_option(self, option: str) -> None:
        await self.controller.async_set_aim(self.aim, self.axis, option)
