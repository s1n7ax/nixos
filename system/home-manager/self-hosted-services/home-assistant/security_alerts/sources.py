"""Where events come from: Frigate over MQTT, and door and motion sensors.

Nothing here names a camera or a sensor. Cameras and sound labels come from
Frigate's config; sensors are any binary_sensor whose device class is door,
motion or occupancy, looked up on every change, so new ones need no edit.
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import Callable, Mapping
from datetime import datetime, timedelta
from functools import partial
from typing import Any

from homeassistant.components import mqtt
from homeassistant.const import (
    ATTR_DEVICE_CLASS,
    ATTR_ENTITY_ID,
    EVENT_STATE_CHANGED,
    STATE_OFF,
    STATE_ON,
)
from homeassistant.core import (
    CALLBACK_TYPE,
    Event,
    EventStateChangedData,
    HomeAssistant,
    callback,
)
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.event import async_call_later, async_track_time_interval
from homeassistant.util.json import json_loads

from .const import (
    FRAME_TIME_TOLERANCE,
    FRIGATE_CONFIG_REFRESH_SECONDS,
    FRIGATE_CONFIG_RETRY_SECONDS,
)
from .core.geometry import Box
from .core.policy import DOOR, MOTION
from .frigate import FrigateError
from .pipeline import SecurityAlerts

_LOGGER = logging.getLogger(__name__)

EVENTS_TOPIC = "frigate/events"
AUDIO_TOPIC = "frigate/+/audio/+"
DOOR_CLASSES = {"door"}
MOTION_CLASSES = {"motion", "occupancy"}
SENSOR_CLASSES = DOOR_CLASSES | MOTION_CLASSES
EXCLUDED_PLATFORMS = {"frigate", "group"}
# Forget a finished Frigate event's boxes a little after its end, in case its
# alert is still waiting for one.
FORGET_AFTER_SECONDS = 60
# Events with no message for this long are forgotten even if their end never came
# (Frigate restarted mid-event, or the end message was lost).
STALE_EVENT_SECONDS = 3600
STALE_SWEEP_INTERVAL = timedelta(minutes=10)


class SnapshotMemory:
    """Every snapshot box seen per active Frigate event, by frame time."""

    def __init__(self) -> None:
        self._boxes: dict[str, dict[float, Box]] = {}
        self._arrivals: dict[str, asyncio.Event] = {}

    def add(self, event_id: str, frame_time: float, box: Box) -> None:
        self._boxes.setdefault(event_id, {})[frame_time] = box
        if (arrival := self._arrivals.pop(event_id, None)) is not None:
            arrival.set()

    def find(self, event_id: str, frame_time: float) -> Box | None:
        for seen, box in self._boxes.get(event_id, {}).items():
            if abs(seen - frame_time) < FRAME_TIME_TOLERANCE:
                return box
        return None

    async def wait_for(self, event_id: str, frame_time: float, timeout: float) -> Box | None:
        """Return the box seen at `frame_time`, waiting up to `timeout` for it."""
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout
        while (box := self.find(event_id, frame_time)) is None:
            remaining = deadline - loop.time()
            if remaining <= 0:
                return None
            arrival = self._arrivals.setdefault(event_id, asyncio.Event())
            try:
                await asyncio.wait_for(arrival.wait(), remaining)
            except TimeoutError:
                return self.find(event_id, frame_time)
        return box

    def forget(self, event_id: str) -> None:
        self._boxes.pop(event_id, None)
        self._arrivals.pop(event_id, None)


def _snapshot(after: dict[str, Any]) -> tuple[float, Box] | None:
    snapshot = after.get("snapshot") or {}
    frame_time = snapshot.get("frame_time")
    box = snapshot.get("box")
    if not isinstance(frame_time, int | float) or not isinstance(box, list) or len(box) != 4:
        return None
    return float(frame_time), (float(box[0]), float(box[1]), float(box[2]), float(box[3]))


class Sources:
    def __init__(self, hass: HomeAssistant, alerts: SecurityAlerts) -> None:
        self.hass = hass
        self.alerts = alerts
        self.snapshots = SnapshotMemory()
        self._alerted: set[str] = set()
        # Last message time per Frigate event, for the stale-event sweep.
        self._seen: dict[str, float] = {}
        self._motion_timers: dict[str, CALLBACK_TYPE] = {}
        self._unsubs: list[Callable[[], None]] = []
        self._config_retry: CALLBACK_TYPE | None = None
        alerts.find_snapshot = self.snapshots.wait_for

    async def async_start(self) -> None:
        self._unsubs.append(
            self.hass.bus.async_listen(
                EVENT_STATE_CHANGED, self._on_state_changed, event_filter=self._is_binary_sensor
            )
        )
        self._unsubs.append(
            async_track_time_interval(
                self.hass,
                self._async_refresh_config,
                timedelta(seconds=FRIGATE_CONFIG_REFRESH_SECONDS),
            )
        )
        self._unsubs.append(
            async_track_time_interval(self.hass, self._sweep_stale, STALE_SWEEP_INTERVAL)
        )
        await self._async_refresh_config()
        if not await mqtt.async_wait_for_mqtt_client(self.hass):
            _LOGGER.error("MQTT is not available; camera alerts are off")
            return
        self._unsubs.append(await mqtt.async_subscribe(self.hass, EVENTS_TOPIC, self._on_event))
        self._unsubs.append(await mqtt.async_subscribe(self.hass, AUDIO_TOPIC, self._on_audio))

    @callback
    def stop(self) -> None:
        for unsub in self._unsubs:
            unsub()
        self._unsubs.clear()
        for cancel in self._motion_timers.values():
            cancel()
        self._motion_timers.clear()
        if self._config_retry:
            self._config_retry()
            self._config_retry = None

    async def _async_refresh_config(self, *_: Any) -> None:
        try:
            await self.alerts.frigate.async_refresh_config()
        except FrigateError as err:
            _LOGGER.warning("Could not read Frigate's config, retrying: %s", err)
            if self._config_retry is None:
                self._config_retry = async_call_later(
                    self.hass, FRIGATE_CONFIG_RETRY_SECONDS, self._retry_config
                )

    @callback
    def _retry_config(self, _now: datetime) -> None:
        self._config_retry = None
        self.hass.async_create_background_task(
            self._async_refresh_config(), "security_alerts frigate config"
        )

    # Frigate

    @callback
    def _on_event(self, msg: mqtt.ReceiveMessage) -> None:
        try:
            payload = json_loads(msg.payload)
        except ValueError:
            return
        if not isinstance(payload, dict):
            return
        after = payload.get("after") or {}
        before = payload.get("before") or {}
        event_id = after.get("id")
        camera = after.get("camera")
        label = after.get("label")
        if not isinstance(event_id, str) or not isinstance(camera, str):
            return
        self._seen[event_id] = time.time()
        snapshot = _snapshot(after)
        if snapshot is not None:
            self.snapshots.add(event_id, *snapshot)

        if (
            isinstance(label, str)
            and after.get("has_clip") is True
            and before.get("has_clip") is not True
            and not after.get("false_positive")
            and event_id not in self._alerted
        ):
            self._alerted.add(event_id)
            start_time = after.get("start_time")
            self.hass.async_create_task(
                self.alerts.async_detection(
                    camera=camera,
                    label=label,
                    event_id=event_id,
                    start_time=float(start_time) if start_time else time.time(),
                    snapshot=snapshot,
                )
            )

        if payload.get("type") == "end":
            end_time = after.get("end_time")
            self.hass.async_create_task(
                self.alerts.async_detection_ended(
                    event_id, float(end_time) if end_time else None, snapshot
                )
            )
            async_call_later(self.hass, FORGET_AFTER_SECONDS, partial(self._forget, event_id))

    @callback
    def _forget(self, event_id: str, _now: datetime | None = None) -> None:
        self.snapshots.forget(event_id)
        self._alerted.discard(event_id)
        self._seen.pop(event_id, None)

    @callback
    def _sweep_stale(self, _now: datetime) -> None:
        cutoff = time.time() - STALE_EVENT_SECONDS
        for event_id in [e for e, seen in self._seen.items() if seen < cutoff]:
            self._forget(event_id)

    @callback
    def _on_audio(self, msg: mqtt.ReceiveMessage) -> None:
        parts = msg.topic.split("/")
        if len(parts) != 4:
            return
        camera, label = parts[1], parts[3]
        if not self.alerts.frigate.listens_for(camera, label):
            return
        payload = msg.payload.decode() if isinstance(msg.payload, bytes) else str(msg.payload)
        if payload == "ON" and not msg.retain:
            self.hass.async_create_task(self.alerts.async_sound(camera, label, time.time()))
        elif payload == "OFF":
            self.hass.async_create_task(self.alerts.async_sound_ended(camera, label, time.time()))

    # Door and motion sensors

    @callback
    def _is_binary_sensor(self, data: EventStateChangedData) -> bool:
        return data["entity_id"].startswith("binary_sensor.")

    def _is_excluded(self, entity_id: str, attributes: Mapping[str, Any]) -> bool:
        if ATTR_ENTITY_ID in attributes:  # a group of other sensors
            return True
        entry = er.async_get(self.hass).async_get(entity_id)
        return entry is not None and entry.platform in EXCLUDED_PLATFORMS

    @callback
    def _on_state_changed(self, event: Event[EventStateChangedData]) -> None:
        old, new = event.data["old_state"], event.data["new_state"]
        if old is None or new is None or old.state == new.state:
            return
        entity_id = new.entity_id
        # Changes from or to unavailable or unknown never alert.
        if old.state not in (STATE_ON, STATE_OFF) or new.state not in (STATE_ON, STATE_OFF):
            self._cancel_motion(entity_id)
            return
        device_class = new.attributes.get(ATTR_DEVICE_CLASS)
        if device_class not in SENSOR_CLASSES:
            return
        if self._is_excluded(entity_id, new.attributes):
            return
        if device_class in DOOR_CLASSES:
            action = "opened" if new.state == STATE_ON else "closed"
            self.hass.async_create_task(self.alerts.async_sensor(DOOR, entity_id, action))
            return
        self._cancel_motion(entity_id)
        if new.state == STATE_ON:
            self._motion_timers[entity_id] = async_call_later(
                self.hass, self.alerts.motion_min_seconds, partial(self._motion_held, entity_id)
            )

    @callback
    def _cancel_motion(self, entity_id: str) -> None:
        if (cancel := self._motion_timers.pop(entity_id, None)) is not None:
            cancel()

    @callback
    def _motion_held(self, entity_id: str, _now: datetime) -> None:
        """Motion stayed on for the minimum time: alert once for this activation."""
        self._motion_timers.pop(entity_id, None)
        state = self.hass.states.get(entity_id)
        if state is None or state.state != STATE_ON:
            return
        self.hass.async_create_task(self.alerts.async_sensor(MOTION, entity_id, None))
