"""Security alerts: camera, sound, door and motion alerts for one phone.

Set up from a `security_alerts:` block in configuration.yaml. The policy (modes,
levels, entity ids) lives there, not in this code, so the camera layout stays
out of version control.
"""

from __future__ import annotations

import hashlib
import logging
from pathlib import Path
from typing import Any

import probatio
from homeassistant.components import frontend, panel_custom
from homeassistant.components.http import StaticPathConfig
from homeassistant.components.lovelace.const import LOVELACE_DATA, MODE_STORAGE
from homeassistant.const import EVENT_HOMEASSISTANT_STOP, STATE_ON, Platform
from homeassistant.core import Event, EventStateChangedData, HomeAssistant, callback
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.discovery import async_load_platform
from homeassistant.helpers.event import async_track_state_change_event
from homeassistant.helpers.typing import ConfigType

from . import services, websocket
from .const import (
    CARD_FILE,
    CONF_BURST_MINUTES,
    CONF_DETECTION,
    CONF_DETECTION_ASLEEP_OR_NIGHT,
    CONF_DOOR_OTHER,
    CONF_DOOR_TOP,
    CONF_DURATIONS_HOURS,
    CONF_ENTITY,
    CONF_FIRST_REVIEW_HOURS,
    CONF_HOME,
    CONF_LOG_DAYS,
    CONF_MODES,
    CONF_MOTION_MIN_SECONDS,
    CONF_MOTION_OTHER,
    CONF_MOTION_TOP,
    CONF_NAME,
    CONF_NIGHT_END,
    CONF_NIGHT_START,
    CONF_NOTIFY_SERVICE,
    CONF_QUIET_AFTER_RESTART_ENTITY,
    CONF_SIREN_ENTITY,
    CONF_SLEEP_ENTITY,
    CONF_SLEEP_THRESHOLD,
    CONF_SOUND,
    CONF_TOP_FLOORS,
    DEFAULT_BURST_MINUTES,
    DEFAULT_DURATIONS_HOURS,
    DEFAULT_FIRST_REVIEW_HOURS,
    DEFAULT_LOG_DAYS,
    DEFAULT_MOTION_MIN_SECONDS,
    DEFAULT_NIGHT_END,
    DEFAULT_NIGHT_START,
    DEFAULT_SLEEP_THRESHOLD,
    DOMAIN,
    FRONTEND_URL,
    PANEL_COMPONENT,
    PANEL_FILE,
    REVIEW_PATH,
)
from .core.policy import LEVELS
from .pipeline import SecurityAlerts
from .sources import Sources
from .views import AudioView, ImageView

_LOGGER = logging.getLogger(__name__)

FRONTEND_DIR = Path(__file__).parent / "frontend"

LEVEL = probatio.In(LEVELS)

MODE_SCHEMA = probatio.Schema(
    {
        probatio.Required(CONF_NAME): cv.string,
        probatio.Required(CONF_ENTITY): cv.entity_id,
        probatio.Required(CONF_DETECTION): LEVEL,
        probatio.Required(CONF_SOUND): LEVEL,
        probatio.Required(CONF_DOOR_TOP): LEVEL,
        probatio.Required(CONF_DOOR_OTHER): LEVEL,
        probatio.Required(CONF_MOTION_TOP): LEVEL,
        probatio.Required(CONF_MOTION_OTHER): LEVEL,
    }
)

HOME_SCHEMA = probatio.Schema(
    {
        probatio.Required(CONF_DETECTION): LEVEL,
        probatio.Required(CONF_DETECTION_ASLEEP_OR_NIGHT): LEVEL,
        probatio.Required(CONF_SOUND): LEVEL,
    }
)

CONFIG_SCHEMA = probatio.Schema(
    {
        DOMAIN: probatio.Schema(
            {
                probatio.Required(CONF_NOTIFY_SERVICE): cv.service,
                # Ladder order: the first mode that is on wins.
                probatio.Required(CONF_MODES): probatio.All(
                    cv.ensure_list, [MODE_SCHEMA], probatio.Length(min=1)
                ),
                probatio.Required(CONF_HOME): HOME_SCHEMA,
                probatio.Optional(CONF_TOP_FLOORS, default=[]): probatio.All(
                    cv.ensure_list, [cv.string]
                ),
                probatio.Required(CONF_SLEEP_ENTITY): cv.entity_id,
                probatio.Optional(
                    CONF_SLEEP_THRESHOLD, default=DEFAULT_SLEEP_THRESHOLD
                ): probatio.Coerce(float),
                probatio.Optional(CONF_NIGHT_START, default=DEFAULT_NIGHT_START): cv.time,
                probatio.Optional(CONF_NIGHT_END, default=DEFAULT_NIGHT_END): cv.time,
                probatio.Optional(
                    CONF_MOTION_MIN_SECONDS, default=DEFAULT_MOTION_MIN_SECONDS
                ): probatio.All(probatio.Coerce(float), probatio.Range(min=0)),
                probatio.Optional(CONF_BURST_MINUTES, default=DEFAULT_BURST_MINUTES): probatio.All(
                    probatio.Coerce(float), probatio.Range(min=0)
                ),
                probatio.Optional(CONF_LOG_DAYS, default=DEFAULT_LOG_DAYS): probatio.All(
                    probatio.Coerce(int), probatio.Range(min=1)
                ),
                probatio.Optional(
                    CONF_FIRST_REVIEW_HOURS, default=DEFAULT_FIRST_REVIEW_HOURS
                ): probatio.All(probatio.Coerce(float), probatio.Range(min=0)),
                probatio.Optional(
                    CONF_DURATIONS_HOURS, default=DEFAULT_DURATIONS_HOURS
                ): probatio.All(cv.ensure_list, [services.HOURS], probatio.Length(min=1)),
                probatio.Optional(CONF_QUIET_AFTER_RESTART_ENTITY): cv.entity_id,
                probatio.Optional(CONF_SIREN_ENTITY): cv.entity_id,
            }
        )
    },
    extra=probatio.ALLOW_EXTRA,
)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    if DOMAIN not in config:
        return True
    conf: dict[str, Any] = config[DOMAIN]

    alerts = SecurityAlerts(hass, conf)
    await alerts.async_setup()
    hass.data[DOMAIN] = alerts

    hass.http.register_view(ImageView(alerts))
    hass.http.register_view(AudioView(alerts))
    websocket.async_register(hass)
    services.async_register(hass, alerts)
    await _async_register_frontend(hass)
    _track_arrival(hass, alerts, [mode.entity for mode in alerts.modes])

    sources = Sources(hass, alerts)
    hass.async_create_background_task(sources.async_start(), "security_alerts sources")
    alerts.add_unsub(sources.stop)
    hass.bus.async_listen_once(EVENT_HOMEASSISTANT_STOP, alerts.async_stop)

    hass.async_create_task(async_load_platform(hass, Platform.SENSOR, DOMAIN, {}, config))
    return True


def _version(*files: Path) -> str:
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.read_bytes())
    return digest.hexdigest()[:12]


async def _async_register_frontend(hass: HomeAssistant) -> None:
    """Serve the panel and card (code only, no data) and load both on dashboards: the
    review panel's module also holds the review tab's card."""
    version = await hass.async_add_executor_job(
        _version, FRONTEND_DIR / PANEL_FILE, FRONTEND_DIR / CARD_FILE
    )
    await hass.http.async_register_static_paths(
        [StaticPathConfig(FRONTEND_URL, str(FRONTEND_DIR), cache_headers=True)]
    )
    # Hidden: no sidebar title. Opened by tapping a notification.
    await panel_custom.async_register_panel(
        hass,
        frontend_url_path=REVIEW_PATH.lstrip("/"),
        webcomponent_name=PANEL_COMPONENT,
        module_url=f"{FRONTEND_URL}/{PANEL_FILE}?v={version}",
        require_admin=False,
    )
    await _async_load_cards(
        hass,
        [f"{FRONTEND_URL}/{CARD_FILE}?v={version}", f"{FRONTEND_URL}/{PANEL_FILE}?v={version}"],
    )


async def _async_load_cards(hass: HomeAssistant, urls: list[str]) -> None:
    """Load the card modules from dashboard resources, each kept at this version.

    Dashboards load their resources after the frontend has booted. An extra JS URL runs at
    page load, racing the frontend's swap of `window.customElements` for its own registry:
    a card defined before the swap is lost ("Custom element doesn't exist").
    """
    lovelace = hass.data[LOVELACE_DATA]
    if lovelace.resource_mode != MODE_STORAGE:
        # YAML resources are read-only here.
        for url in urls:
            frontend.add_extra_js_url(hass, url)
        return
    resources = lovelace.resources
    await resources.async_get_info()  # Loads the collection from storage.
    for url in urls:
        path = url.partition("?")[0]
        items = resources.async_items()
        item = next((i for i in items if i["url"].partition("?")[0] == path), None)
        if item is None:
            await resources.async_create_item({"res_type": "module", "url": url})
        elif item["url"] != url or item["type"] != "module":
            await resources.async_update_item(item["id"], {"res_type": "module", "url": url})


@callback
def _track_arrival(hass: HomeAssistant, alerts: SecurityAlerts, entities: list[str]) -> None:
    """Arriving home (every away mode off) ends every Pause, Do-not-disturb and Snooze."""

    @callback
    def changed(event: Event[EventStateChangedData]) -> None:
        changed_id = event.data["entity_id"]
        old, new = event.data["old_state"], event.data["new_state"]
        others_on = any(
            (state := hass.states.get(entity)) is not None and state.state == STATE_ON
            for entity in entities
            if entity != changed_id
        )
        was_on = others_on or (old is not None and old.state == STATE_ON)
        is_on = others_on or (new is not None and new.state == STATE_ON)
        if was_on and not is_on:
            ended = alerts.end_all_quiet()
            if ended:
                _LOGGER.info("Arrived home: ended %d quiet entries", ended)

    alerts.add_unsub(async_track_state_change_event(hass, entities, changed))
