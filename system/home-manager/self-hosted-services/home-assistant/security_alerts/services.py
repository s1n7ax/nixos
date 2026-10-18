"""Services, and the companion app's notification buttons."""

from __future__ import annotations

from typing import Any

import probatio
from homeassistant.core import (
    Event,
    HomeAssistant,
    ServiceCall,
    ServiceResponse,
    SupportsResponse,
    callback,
)
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.service import async_register_admin_service

from .const import ACTION_SIREN, ACTION_SNOOZE_PREFIX, DOMAIN
from .core.policy import EVENT_KINDS
from .core.quiet import DND, PAUSE, SNOOZE
from .pipeline import Overrides, SecurityAlerts

NOTIFICATION_ACTION_EVENT = "mobile_app_notification_action"

# How long a Pause, Do-not-disturb or Snooze may run.
HOURS = probatio.All(probatio.Coerce(float), probatio.Range(min=0.01, max=24 * 30))
# The fields of a new quiet entry, shared with the websocket command.
QUIET_FIELDS = {
    probatio.Required("types"): probatio.All(cv.ensure_list, [cv.string], probatio.Length(min=1)),
    probatio.Optional("cameras", default=[]): probatio.All(cv.ensure_list, [cv.string]),
    probatio.Required("hours"): HOURS,
}
QUIET_SCHEMA = probatio.Schema(QUIET_FIELDS)
END_SCHEMA = probatio.Schema({probatio.Required("entry_id"): cv.string})
SIMULATE_SCHEMA = probatio.Schema(
    {
        probatio.Required("kind"): probatio.In(EVENT_KINDS),
        probatio.Optional("type"): cv.string,
        probatio.Optional("camera"): cv.string,
        probatio.Optional("entity_id"): cv.entity_id,
        probatio.Optional("action"): probatio.In(["opened", "closed"]),
        probatio.Optional("seconds"): probatio.All(probatio.Coerce(float), probatio.Range(min=0)),
        probatio.Optional("box"): probatio.All(
            [probatio.Coerce(float)], probatio.Length(min=4, max=4)
        ),
        probatio.Optional("mode"): cv.string,
        probatio.Optional("asleep"): cv.boolean,
        probatio.Optional("time"): cv.time,
        probatio.Optional("notify", default=False): cv.boolean,
    }
)


@callback
def async_register(hass: HomeAssistant, alerts: SecurityAlerts) -> None:
    def quiet_handler(kind: str):
        async def handle(call: ServiceCall) -> ServiceResponse:
            entries = alerts.add_quiet(
                kind, call.data["types"], call.data["cameras"], call.data["hours"]
            )
            return {"entries": [e.as_dict() for e in entries]}

        return handle

    for kind in (SNOOZE, PAUSE, DND):
        hass.services.async_register(
            DOMAIN,
            kind,
            quiet_handler(kind),
            schema=QUIET_SCHEMA,
            supports_response=SupportsResponse.OPTIONAL,
        )

    async def end(call: ServiceCall) -> None:
        alerts.end_quiet(call.data["entry_id"])

    async def end_all(call: ServiceCall) -> None:
        alerts.end_all_quiet()

    async def trigger_siren(call: ServiceCall) -> ServiceResponse:
        triggered, message = await alerts.async_trigger_siren(notify_phone=True)
        return {"triggered": triggered, "message": message}

    async def simulate(call: ServiceCall) -> ServiceResponse:
        data: dict[str, Any] = call.data
        box = data.get("box")
        return await alerts.async_simulate(
            kind=data["kind"],
            event_type=data.get("type"),
            camera=data.get("camera"),
            entity_id=data.get("entity_id"),
            action=data.get("action"),
            seconds=data.get("seconds"),
            box=(box[0], box[1], box[2], box[3]) if box else None,
            overrides=Overrides(
                mode=data.get("mode"), asleep=data.get("asleep"), at=data.get("time")
            ),
            notify=data["notify"],
        )

    hass.services.async_register(DOMAIN, "end", end, schema=END_SCHEMA)
    hass.services.async_register(DOMAIN, "end_all", end_all)
    hass.services.async_register(
        DOMAIN, "trigger_siren", trigger_siren, supports_response=SupportsResponse.OPTIONAL
    )
    async_register_admin_service(
        hass,
        DOMAIN,
        "simulate",
        simulate,
        schema=SIMULATE_SCHEMA,
        supports_response=SupportsResponse.OPTIONAL,
    )

    async def on_notification_action(event: Event) -> None:
        action = event.data.get("action")
        if not isinstance(action, str):
            return
        if action == ACTION_SIREN:
            await alerts.async_trigger_siren(notify_phone=True)
        elif action.startswith(ACTION_SNOOZE_PREFIX) and len(action) > len(ACTION_SNOOZE_PREFIX):
            await alerts.async_snooze_from_notification(action[len(ACTION_SNOOZE_PREFIX) :])

    alerts.add_unsub(hass.bus.async_listen(NOTIFICATION_ACTION_EVENT, on_notification_action))
