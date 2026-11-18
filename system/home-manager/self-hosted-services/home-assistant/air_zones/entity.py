"""The base every air_zones entity shares: one device, refreshed on each controller update."""

from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity import Entity

from . import DOMAIN, SIGNAL, AirZones

NAMES = {
    "my_desk": "My desk",
    "bed": "Bed",
    "bed_sleep": "Bed while asleep",
    "wife_desk": "Wife's desk",
}


class AirZonesEntity(Entity):
    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, controller: AirZones, key: str) -> None:
        self.controller = controller
        self._attr_unique_id = f"{DOMAIN}_{key}"
        self._attr_device_info = DeviceInfo(identifiers={(DOMAIN, DOMAIN)}, name="Air zones")

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL, self.async_write_ha_state))
