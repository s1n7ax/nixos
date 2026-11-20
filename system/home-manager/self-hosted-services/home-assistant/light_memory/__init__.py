"""Light memory: a light turned on without a brightness or colour comes back as it was last set.

Set up from a `light_memory:` line in configuration.yaml; `entities` defaults to the office bulbs.
Those bulbs (Tuya TS0505B) lose a level set shortly before they were turned off and come back at
an older one. So Home Assistant remembers each light's brightness and colour while it is on, and
adds them to a turn-on that gives none: the bulb gets one command with the level and comes on
right the first time, with no blink at the old level.

Every turn-on through Home Assistant gets it, `light.turn_on` and `light.toggle` alike, because
both end in the light entity's `async_turn_on`, which this wraps.
"""

from __future__ import annotations

import logging
from typing import Any

import voluptuous as vol
from homeassistant.components.light.const import DATA_COMPONENT
from homeassistant.const import STATE_ON
from homeassistant.core import Event, EventStateChangedData, HomeAssistant, State, callback
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.event import async_track_state_change_event
from homeassistant.helpers.storage import Store
from homeassistant.helpers.typing import ConfigType

from . import memory

_LOGGER = logging.getLogger(__name__)

DOMAIN = "light_memory"
CONF_ENTITIES = "entities"
OFFICE_LIGHTS = ["light.b_office_srinesh", "light.b_office_nidu"]

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {vol.Optional(CONF_ENTITIES, default=OFFICE_LIGHTS): cv.entity_ids},
        )
    },
    extra=vol.ALLOW_EXTRA,
)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    if DOMAIN not in config:
        return True
    lights = LightMemory(hass, config[DOMAIN][CONF_ENTITIES])
    await lights.async_load()
    lights.start()
    return True


class LightMemory:
    """Remembers what each light was last set to and hands it to a plain turn-on."""

    def __init__(self, hass: HomeAssistant, entities: list[str]) -> None:
        self.hass = hass
        self.entities = entities
        self.store = Store(hass, 1, DOMAIN)
        self.settings: dict[str, memory.Setting] = {}
        # The entity object wrapped for each light. MQTT can replace it, e.g. on a reload.
        self.wrapped: dict[str, Any] = {}

    async def async_load(self) -> None:
        data = await self.store.async_load() or {}
        self.settings = {k: v for k, v in data.get("settings", {}).items() if k in self.entities}

    @callback
    def _save(self) -> None:
        self.store.async_delay_save(lambda: {"settings": self.settings}, 1)

    @callback
    def start(self) -> None:
        """Watch the lights from setup on, so a turn-on while HA is still starting is covered."""
        async_track_state_change_event(self.hass, self.entities, self._changed)
        for entity_id in self.entities:
            self._remember(self.hass.states.get(entity_id))
            # A light MQTT has not set up yet is wrapped when it first reports.
            if not self._wrap(entity_id):
                _LOGGER.debug("%s not there yet; wrapping it when it reports", entity_id)

    @callback
    def _changed(self, event: Event[EventStateChangedData]) -> None:
        self._remember(event.data["new_state"])
        self._wrap(event.data["entity_id"])

    @callback
    def _remember(self, state: State | None) -> None:
        """Only an on light's report counts: the bulbs report a stale level while off."""
        if state is None or state.state != STATE_ON:
            return
        setting = memory.setting(dict(state.attributes))
        if setting is None or setting == self.settings.get(state.entity_id):
            return
        self.settings[state.entity_id] = setting
        self._save()

    @callback
    def _wrap(self, entity_id: str) -> bool:
        """Wrap the light's `async_turn_on`, once per entity object. False if it is missing."""
        component = self.hass.data.get(DATA_COMPONENT)
        entity = component.get_entity(entity_id) if component else None
        if entity is None:
            return False
        if self.wrapped.get(entity_id) is entity:
            return True
        turn_on = entity.async_turn_on

        async def async_turn_on(**kwargs: Any) -> None:
            if not entity.is_on:
                kwargs = memory.fill(kwargs, self.settings.get(entity_id))
            await turn_on(**kwargs)

        entity.async_turn_on = async_turn_on
        self.wrapped[entity_id] = entity
        return True
