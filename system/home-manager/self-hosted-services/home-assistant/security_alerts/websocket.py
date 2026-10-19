"""Websocket commands for the review page and the dashboard card.

Results carry image, audio and clip URLs signed for the logged-in user, because
plain <img>, <audio> and <video> requests send no token.
"""

from __future__ import annotations

import time
from datetime import timedelta
from typing import Any

import probatio
from homeassistant.components import websocket_api
from homeassistant.components.http.auth import async_sign_path
from homeassistant.core import HomeAssistant, callback
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import config_validation as cv

from .const import (
    AUDIO_URL,
    DOMAIN,
    FULL,
    IMAGE_URL,
    SIGNED_URL_HOURS,
)
from .core.icons import icon_for
from .core.policy import DETECTION, SENSOR_KINDS, SOUND
from .core.quiet import QUIET_KINDS, changed_kinds
from .notify import local_clock, type_name
from .pipeline import SecurityAlerts
from .services import QUIET_FIELDS
from .store import AlertRow

SIGNED_FOR = timedelta(hours=SIGNED_URL_HOURS)
CLIP_URL = "/api/frigate/recording/{camera}/start/{start}/end/{end}"


def _alerts(hass: HomeAssistant) -> SecurityAlerts:
    return hass.data[DOMAIN]


def _item(hass: HomeAssistant, alerts: SecurityAlerts, row: AlertRow, now: float) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": row.id,
        "time": row.time,
        "clock": local_clock(row.time),
        "kind": row.kind,
        "type": row.type,
        "type_name": type_name(row.type),
        "source": row.source,
        "name": row.name,
        "action": row.action,
        "delivery": row.delivery,
        "mode": row.mode,
    }
    if row.kind not in (DETECTION, SOUND):
        return item
    item["camera_entity"] = alerts.camera_entity(row.source)
    clip: dict[str, Any] = {"ready": False, "url": None}
    if (window := alerts.clip_window(row)) is not None:
        start, end = window
        clip["ready"] = alerts.clip_ready(window, now)
        if clip["ready"]:
            clip["url"] = async_sign_path(
                hass, CLIP_URL.format(camera=row.source, start=start, end=end), SIGNED_FOR
            )
    item["clip"] = clip
    if row.kind == DETECTION:
        item["image"] = async_sign_path(
            hass, IMAGE_URL.format(alert_id=row.id, variant=FULL), SIGNED_FOR
        )
    else:
        # A sound shows no picture: it plays its audio, cut from the same clip.
        item["audio"] = {
            "ready": clip["ready"],
            "url": async_sign_path(hass, AUDIO_URL.format(alert_id=row.id), SIGNED_FOR)
            if clip["ready"]
            else None,
        }
    return item


def _window(
    hass: HomeAssistant, start: float, end: float, rows: list[AlertRow], more: bool
) -> dict[str, Any]:
    """One page of a review window; `more` says another page follows the last item."""
    alerts = _alerts(hass)
    now = time.time()
    return {
        "from": start,
        "to": end,
        "from_clock": local_clock(start),
        "to_clock": local_clock(end),
        "items": [_item(hass, alerts, row, now) for row in rows],
        "more": more,
    }


@websocket_api.websocket_command({probatio.Required("type"): "security_alerts/review/start"})
@websocket_api.async_response
async def ws_review_start(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Record a review and return everything since the last one."""
    start, end, rows, more = await _alerts(hass).async_review_start()
    connection.send_result(msg["id"], _window(hass, start, end, rows, more))


@websocket_api.websocket_command(
    {
        probatio.Required("type"): "security_alerts/review/get",
        probatio.Optional("from"): probatio.Coerce(float),
        probatio.Optional("to"): probatio.Coerce(float),
        # The last item of the previous page, to fetch the next one.
        probatio.Inclusive("after_time", "after"): probatio.Coerce(float),
        probatio.Inclusive("after_id", "after"): probatio.Match(r"^[0-9a-f]{32}$"),
    }
)
@websocket_api.async_response
async def ws_review_get(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """Return a window page without recording a review (defaults: last review to now)."""
    alerts = _alerts(hass)
    now = time.time()
    end = msg.get("to", now)
    start = msg.get("from", alerts.review_start_default(now))
    after = (msg["after_time"], msg["after_id"]) if "after_id" in msg else None
    rows, more = await alerts.async_window(start, end, after)
    connection.send_result(msg["id"], _window(hass, start, end, rows, more))


@websocket_api.websocket_command(
    {
        probatio.Required("type"): "security_alerts/alert",
        probatio.Required("alert_id"): probatio.Match(r"^[0-9a-f]{32}$"),
    }
)
@websocket_api.async_response
async def ws_alert(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    alerts = _alerts(hass)
    row = await alerts.async_get(msg["alert_id"])
    if row is None:
        connection.send_error(msg["id"], websocket_api.ERR_NOT_FOUND, "No such alert")
        return
    connection.send_result(msg["id"], _item(hass, alerts, row, time.time()))


@websocket_api.websocket_command({probatio.Required("type"): "security_alerts/types"})
@callback
def ws_types(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    """The types and cameras the pickers offer, the durations, and the modes.

    Each mode, in ladder order, lists per quiet kind the event kinds it changes
    there, so the card offers only those types for the mode that is on.
    """
    alerts = _alerts(hass)
    typed = [(label, DETECTION) for label in alerts.frigate.object_labels()]
    typed += [(label, SOUND) for label in alerts.frigate.sound_labels()]
    typed += [(kind, kind) for kind in SENSOR_KINDS]
    types = [
        {"id": type_id, "name": type_name(type_id), "kind": kind, "icon": icon_for(kind, type_id)}
        for type_id, kind in typed
    ]
    cameras = [
        {"id": camera, "name": alerts.camera_name(camera)}
        for camera in alerts.frigate.camera_names()
    ]
    modes = [
        {"name": mode.name, "entity": mode.entity, "changes": changed_kinds(mode)}
        for mode in alerts.modes
    ]
    connection.send_result(
        msg["id"],
        {
            "types": types,
            "cameras": cameras,
            "durations": alerts.durations_hours,
            "modes": modes,
        },
    )


@websocket_api.websocket_command({probatio.Required("type"): "security_alerts/quiet/list"})
@callback
def ws_quiet_list(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    entries = _alerts(hass).running_quiet()
    connection.send_result(msg["id"], {"entries": [e.as_dict() for e in entries]})


@websocket_api.websocket_command(
    {
        probatio.Required("type"): "security_alerts/quiet/add",
        probatio.Required("kind"): probatio.In(QUIET_KINDS),
        **QUIET_FIELDS,
    }
)
@callback
def ws_quiet_add(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    try:
        entries = _alerts(hass).add_quiet(msg["kind"], msg["types"], msg["cameras"], msg["hours"])
    except ServiceValidationError as err:
        connection.send_error(msg["id"], websocket_api.ERR_INVALID_FORMAT, str(err))
        return
    connection.send_result(msg["id"], {"entries": [e.as_dict() for e in entries]})


@websocket_api.websocket_command(
    {
        probatio.Required("type"): "security_alerts/quiet/end",
        probatio.Required("entry_id"): cv.string,
    }
)
@callback
def ws_quiet_end(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    if not _alerts(hass).end_quiet(msg["entry_id"]):
        connection.send_error(msg["id"], websocket_api.ERR_NOT_FOUND, "No such entry")
        return
    connection.send_result(msg["id"], {})


@websocket_api.websocket_command({probatio.Required("type"): "security_alerts/siren"})
@websocket_api.async_response
async def ws_siren(
    hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]
) -> None:
    triggered, message = await _alerts(hass).async_trigger_siren(notify_phone=False)
    connection.send_result(msg["id"], {"triggered": triggered, "message": message})


@callback
def async_register(hass: HomeAssistant) -> None:
    for command in (
        ws_review_start,
        ws_review_get,
        ws_alert,
        ws_types,
        ws_quiet_list,
        ws_quiet_add,
        ws_quiet_end,
        ws_siren,
    ):
        websocket_api.async_register_command(hass, command)
