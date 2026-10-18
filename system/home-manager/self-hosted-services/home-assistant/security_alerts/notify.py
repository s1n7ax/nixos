"""Companion-app notification payloads and the calls that send or clear them."""

from __future__ import annotations

import logging
from collections.abc import Iterable
from datetime import datetime
from typing import Any

from homeassistant.core import HomeAssistant
from homeassistant.exceptions import HomeAssistantError
from homeassistant.util import dt as dt_util
from probatio import Invalid

from .const import (
    ACTION_SIREN,
    ACTION_SNOOZE_PREFIX,
    IMAGE_URL,
    REVIEW_PATH,
    THUMB,
)
from .core.decide import POPUP
from .core.policy import CRITICAL, DETECTION, DOOR, MOTION, REGULAR, SILENT, SOUND

_LOGGER = logging.getLogger(__name__)

# Delivery -> (channel, importance). New channel names, because Android fixes a
# channel's importance the first time it is used.
CHANNELS = {
    CRITICAL: ("alarm_stream", "high"),
    POPUP: ("Security popup", "high"),
    REGULAR: ("Security regular", "high"),
    SILENT: ("Security silent", "low"),
}

ICONS = {
    DETECTION: "mdi:cctv",
    SOUND: "mdi:waveform",
    DOOR: "mdi:door",
    MOTION: "mdi:motion-sensor",
}

SIREN_TAG = "security-siren"


def tag_for(event_type: str) -> str:
    return f"security-{event_type}"


def type_name(event_type: str) -> str:
    """'fire_alarm' -> 'Fire alarm'."""
    text = event_type.replace("_", " ").strip()
    return text[:1].upper() + text[1:]


def clock(when: datetime) -> str:
    """12-hour time, like '10:42 PM'."""
    return f"{when.hour % 12 or 12}:{when.minute:02d} {'AM' if when.hour < 12 else 'PM'}"


def local_clock(timestamp: float) -> str:
    return clock(dt_util.as_local(dt_util.utc_from_timestamp(timestamp)))


def alert_text(
    kind: str, event_type: str, name: str, action: str | None, timestamp: float
) -> tuple[str, str]:
    """Return (title, message) for one alert."""
    when = local_clock(timestamp)
    if kind == DETECTION:
        return f"{type_name(event_type)} detected", f"{name} · {when}"
    if kind == SOUND:
        return f"{type_name(event_type)} heard", f"{name} · {when}"
    if kind == DOOR:
        return f"{name} {action or 'opened'}", when
    return f"Motion: {name}", when


def _base_data(tag: str, delivery: str) -> dict[str, Any]:
    channel, importance = CHANNELS[delivery]
    return {
        "tag": tag,
        "channel": channel,
        "importance": importance,
        "priority": "high",
        "ttl": 0,
        "car_ui": True,
        "alert_once": False,
        "clickAction": REVIEW_PATH,
    }


def alert_payload(
    *,
    alert_id: str,
    kind: str,
    event_type: str,
    title: str,
    message: str,
    delivery: str,
    has_image: bool,
) -> dict[str, Any]:
    """The notify service data for one alert."""
    data = _base_data(tag_for(event_type), delivery)
    data["notification_icon"] = ICONS.get(kind, "mdi:shield-alert")
    if has_image:
        data["image"] = IMAGE_URL.format(alert_id=alert_id, variant=THUMB)
    actions: list[dict[str, str]] = []
    if kind in (DETECTION, SOUND):
        actions.append(
            {"action": "URI", "title": "Play clip", "uri": f"{REVIEW_PATH}?clip={alert_id}"}
        )
    actions.append({"action": ACTION_SIREN, "title": "Trigger siren"})
    actions.append({"action": f"{ACTION_SNOOZE_PREFIX}{event_type}", "title": "Snooze 1 hour"})
    data["actions"] = actions
    return {"title": title, "message": message, "data": data}


def snoozed_payload(event_type: str, until: float) -> dict[str, Any]:
    """Quietly replaces a type's notification after Snooze 1 hour."""
    return {
        "title": f"{type_name(event_type)} snoozed until {local_clock(until)}",
        "message": "Security alerts of this type arrive silent until then.",
        "data": {**_base_data(tag_for(event_type), SILENT), "notification_icon": "mdi:bell-sleep"},
    }


def siren_missing_payload() -> dict[str, Any]:
    return {
        "title": "No siren is set up",
        "message": "Trigger siren does nothing until a siren is added.",
        "data": {**_base_data(SIREN_TAG, REGULAR), "notification_icon": "mdi:alarm-light-off"},
    }


class Notifier:
    """Sends through one notify service, such as notify.mobile_app_pixel."""

    def __init__(self, hass: HomeAssistant, service: str) -> None:
        self._hass = hass
        self._domain, self._service = service.split(".", 1)

    async def async_send(self, payload: dict[str, Any]) -> bool:
        try:
            await self._hass.services.async_call(
                self._domain, self._service, payload, blocking=True
            )
        except (HomeAssistantError, Invalid) as err:
            _LOGGER.error("Could not send a security notification: %s", err)
            return False
        return True

    async def async_clear(self, tags: Iterable[str]) -> None:
        for tag in tags:
            await self.async_send({"message": "clear_notification", "data": {"tag": tag}})
