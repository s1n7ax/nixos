"""Energy meters: keeps the Energy dashboard's "Individual devices" in sync with the meters.

Set up from a bare `energy_meters:` line in configuration.yaml. Every energy meter on a
device (smart plugs etc.) is added, deleted and excluded ones are dropped, and entries
added by hand in the UI are left alone. Give an entity the `energy_exclude` label in Home
Assistant to keep it off the dashboard. The rules live in `meters.py`.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from homeassistant.components.energy.data import async_get_manager
from homeassistant.core import CALLBACK_TYPE, Event, HomeAssistant, callback
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.event import async_call_later, async_track_time_interval
from homeassistant.helpers.start import async_at_started
from homeassistant.helpers.typing import ConfigType

from .meters import Entity, sync

_LOGGER = logging.getLogger(__name__)

DOMAIN = "energy_meters"
# The meters need their states, which integrations still write right after the start.
STARTUP_DELAY_SECONDS = 60
INTERVAL = timedelta(days=1)
# A device joining or leaving changes the registry many times; sync once it goes quiet.
REGISTRY_QUIET_SECONDS = 30


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    if DOMAIN not in config:
        return True
    cancel_quiet_wait: CALLBACK_TYPE | None = None

    async def sync_now(_now: datetime) -> None:
        await _async_sync(hass)

    @callback
    def registry_changed(_event: Event[er.EventEntityRegistryUpdatedData]) -> None:
        nonlocal cancel_quiet_wait
        if cancel_quiet_wait is not None:
            cancel_quiet_wait()
        cancel_quiet_wait = async_call_later(hass, REGISTRY_QUIET_SECONDS, sync_now)

    @callback
    def start(hass: HomeAssistant) -> None:
        async_call_later(hass, STARTUP_DELAY_SECONDS, sync_now)
        async_track_time_interval(hass, sync_now, INTERVAL)
        hass.bus.async_listen(er.EVENT_ENTITY_REGISTRY_UPDATED, registry_changed)

    async_at_started(hass, start)
    return True


async def _async_sync(hass: HomeAssistant) -> None:
    manager = await async_get_manager(hass)
    if manager.data is None:
        # The Energy dashboard was never set up; leave that to the user.
        return
    entities = [
        Entity(
            entity_id=entry.entity_id,
            device_id=entry.device_id,
            platform=entry.platform,
            disabled=entry.disabled,
            labels=frozenset(entry.labels),
            attributes=state.attributes if (state := hass.states.get(entry.entity_id)) else {},
        )
        for entry in er.async_get(hass).entities.values()
    ]
    changes = sync(entities, manager.data["device_consumption"])
    if not changes.added and not changes.removed:
        return
    _LOGGER.info("Energy devices added=%s removed=%s", changes.added, changes.removed)
    await manager.async_update({"device_consumption": changes.devices})
