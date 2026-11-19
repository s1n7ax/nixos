"""The base every air_zones entity shares: one device, refreshed on each controller update."""

from __future__ import annotations

from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity import Entity

from . import DOMAIN, SIGNAL, AirZones

NAMES = {
    "my_desk": "my desk",
    "bed": "bed",
    "bed_sleep": "bed while asleep",
    "wife_desk": "wife's desk",
}


class AirZonesEntity(Entity):
    """Ids are fixed (`<platform>.air_zones_<key>`): the Frequent card reads them by name.

    Set up from YAML, without a config entry, so there is no device to name them after.
    """

    _attr_should_poll = False

    platform_name: str

    def __init__(self, controller: AirZones, key: str, name: str) -> None:
        self.controller = controller
        self._attr_unique_id = f"{DOMAIN}_{key}"
        self.entity_id = f"{self.platform_name}.{DOMAIN}_{key}"
        self._attr_name = f"Air zones {name}"

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL, self.async_write_ha_state))
