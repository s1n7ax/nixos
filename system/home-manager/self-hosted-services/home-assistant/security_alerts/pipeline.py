"""The hub: one event in, a decision, a log row, an image and a notification out.

It also owns the quiet entries, the review window and the siren action, so the
websocket commands, views and services all go through one object.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import math
import time
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from dataclasses import dataclass, field
from datetime import time as dt_time
from datetime import timedelta
from pathlib import Path
from typing import Any

from homeassistant.const import STATE_ON
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, State, callback
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import area_registry as ar
from homeassistant.helpers import device_registry as dr
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import (
    async_track_point_in_utc_time,
    async_track_time_interval,
)
from homeassistant.util import dt as dt_util

from . import imaging, matching
from .const import (
    AUDIO,
    CLIP_FALLBACK_LENGTH_SECONDS,
    CLIP_MISSING_END_SECONDS,
    CLIP_POST_SECONDS,
    CLIP_PRE_SECONDS,
    CLIP_READY_DELAY_SECONDS,
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
    FFMPEG_TIMEOUT_SECONDS,
    FRAME_TIME_TOLERANCE,
    FULL,
    FULL_IMAGE_VERSION,
    MATCH_CONCURRENCY,
    MATCH_WINDOW_SECONDS,
    SIGNAL_ALERT_LOGGED,
    SIGNAL_QUIET_UPDATED,
    SNAPSHOT_MATCH_TIMEOUT_SECONDS,
    SNOOZE_ACTION_HOURS,
    THUMB,
)
from .core.burst import BurstWindow
from .core.decide import Decision, decide
from .core.geometry import Box, Size, scale_box, thumbnail_crop
from .core.policy import (
    DETECTION,
    DOOR,
    HOME,
    MOTION,
    NONE,
    SOUND,
    HomeRules,
    Mode,
    active_mode,
    base_level,
    is_asleep,
    is_night,
)
from .core.quiet import SNOOZE, QuietEntry, new_entries, next_expiry, running
from .frigate import FrigateClient, FrigateError
from .notify import (
    SIREN_TAG,
    Notifier,
    alert_payload,
    alert_text,
    siren_missing_payload,
    snoozed_payload,
    type_name,
)
from .store import AlertLog, AlertLogError, AlertRow, StateStore

_LOGGER = logging.getLogger(__name__)

PRUNE_INTERVAL = timedelta(days=1)
REVIEW_PAGE_SIZE = 100
CLIP_END_CHECK_INTERVAL = timedelta(minutes=5)
# A review image rendered from Frigate's snapshot instead of the matched
# recording frame is cached only once the recording should exist, so an early
# look does not stick.
FULL_FALLBACK_CACHE_AFTER_SECONDS = 10 * 60


@dataclass
class AlertEvent:
    """One detection, sound, door or motion event, before the decision."""

    kind: str
    type: str
    source: str
    name: str
    time: float
    camera: str | None = None
    top_floor: bool = False
    action: str | None = None
    event_id: str | None = None
    snapshot_time: float | None = None
    snapshot_box: Box | None = None
    clip_start: float | None = None
    clip_end: float | None = None


@dataclass
class Overrides:
    """Simulation overrides for the facts that decide the level."""

    mode: str | None = None
    asleep: bool | None = None
    at: dt_time | None = None


@dataclass
class _PendingEnd:
    """The end of a detection whose log row is still being written."""

    end: float | None = None
    snapshot: tuple[float, Box] | None = None


@dataclass
class _MediaLock:
    """One alert's media file being made, and how many requests hold or wait for it."""

    lock: asyncio.Lock = field(default_factory=asyncio.Lock)
    users: int = 0


@dataclass
class _Snapshot:
    """Frigate's clean event snapshot and the box drawn on that very frame, in its pixels."""

    frame: bytes
    size: Size
    frame_time: float
    box: Box


class AudioClipError(Exception):
    """ffmpeg could not cut a sound's audio clip."""


def _new_id() -> str:
    return uuid.uuid4().hex


def _event_box(event: dict[str, Any], frame_time: float, size: Size) -> Box | None:
    """The event API's snapshot box in `size` pixels, if it was drawn at `frame_time`.

    Frigate gives it relative to the frame, as (x, y, width, height).
    """
    data = event.get("data")
    if not isinstance(data, dict):
        return None
    box, box_time = data.get("box"), data.get("snapshot_frame_time")
    if not isinstance(box_time, int | float) or abs(box_time - frame_time) >= FRAME_TIME_TOLERANCE:
        return None
    if not isinstance(box, list) or len(box) != 4:
        return None
    if not all(isinstance(v, int | float) for v in box):
        return None
    x, y, w, h = box
    return (x * size[0], y * size[1], (x + w) * size[0], (y + h) * size[1])


async def _async_ffmpeg(*args: str) -> None:
    """Run ffmpeg (from PATH) with `args`, killing it after FFMPEG_TIMEOUT_SECONDS.

    Raises:
        AudioClipError: ffmpeg could not start, failed or timed out.
    """
    try:
        process = await asyncio.create_subprocess_exec(
            "ffmpeg",
            "-nostdin",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            *args,
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
    except OSError as err:
        raise AudioClipError(f"Could not run ffmpeg: {err}") from err
    try:
        async with asyncio.timeout(FFMPEG_TIMEOUT_SECONDS):
            _, stderr = await process.communicate()
    except TimeoutError as err:
        raise AudioClipError(f"ffmpeg took more than {FFMPEG_TIMEOUT_SECONDS} s") from err
    finally:
        # Timed out or cancelled: never leave it running.
        if process.returncode is None:
            with contextlib.suppress(ProcessLookupError):
                process.kill()
            await process.wait()
    if process.returncode != 0:
        lines = stderr.decode(errors="replace").strip().splitlines()
        raise AudioClipError(
            f"ffmpeg exited with {process.returncode}: {lines[-1] if lines else 'no output'}"
        )


class SecurityAlerts:
    def __init__(self, hass: HomeAssistant, config: dict[str, Any]) -> None:
        self.hass = hass
        self.config = config
        self.modes = [
            Mode(
                name=m[CONF_NAME],
                entity=m[CONF_ENTITY],
                detection=m[CONF_DETECTION],
                sound=m[CONF_SOUND],
                door_top=m[CONF_DOOR_TOP],
                door_other=m[CONF_DOOR_OTHER],
                motion_top=m[CONF_MOTION_TOP],
                motion_other=m[CONF_MOTION_OTHER],
            )
            for m in config[CONF_MODES]
        ]
        home = config[CONF_HOME]
        self.home = HomeRules(
            detection=home[CONF_DETECTION],
            detection_asleep_or_night=home[CONF_DETECTION_ASLEEP_OR_NIGHT],
            sound=home[CONF_SOUND],
        )
        self.top_floors = set(config[CONF_TOP_FLOORS])
        self.motion_min_seconds: float = config[CONF_MOTION_MIN_SECONDS]
        self.durations_hours: list[float] = config[CONF_DURATIONS_HOURS]
        self.state = StateStore(hass)
        self.log = AlertLog(hass.config.config_dir)
        self.frigate = FrigateClient(hass)
        self.notifier = Notifier(hass, config[CONF_NOTIFY_SERVICE])
        self.burst = BurstWindow(config[CONF_BURST_MINUTES] * 60)
        # Set by Sources once it starts; finds the MQTT box for a snapshot frame.
        self.find_snapshot: Callable[[str, float, float], Awaitable[Box | None]] | None = None
        self._quiet: list[QuietEntry] = []
        # The last send started per type; each send waits for the one before it.
        self._sends: dict[str, asyncio.Future[None]] = {}
        self._pending_ends: dict[str, _PendingEnd] = {}
        self._active_sounds: dict[tuple[str, str], str | None] = {}
        self._pending_offs: dict[tuple[str, str], float] = {}
        self._media_locks: dict[tuple[str, str], _MediaLock] = {}
        # Each frame match takes a core for a second or two.
        self._match_slots = asyncio.Semaphore(MATCH_CONCURRENCY)
        # Review images to render once their recording is saved, by alert id.
        self._render_timers: dict[str, CALLBACK_TYPE] = {}
        self._expiry_unsub: CALLBACK_TYPE | None = None
        self._unsubs: list[CALLBACK_TYPE] = []

    # Lifecycle

    async def async_setup(self) -> None:
        await self.state.async_load()
        self._quiet = [QuietEntry.from_dict(d) for d in self.state.quiet]
        self.burst = BurstWindow(self.burst.window_seconds, self.state.last_rings)
        await self.hass.async_add_executor_job(self.log.open)
        self._drop_expired()
        self._schedule_expiry()
        self._unsubs.append(async_track_time_interval(self.hass, self._async_prune, PRUNE_INTERVAL))
        self._unsubs.append(
            async_track_time_interval(
                self.hass, self._async_fill_missing_clip_ends, CLIP_END_CHECK_INTERVAL
            )
        )
        self.hass.async_create_background_task(self._async_prune(), "security_alerts prune")
        self.hass.async_create_background_task(
            self._async_fill_missing_clip_ends(), "security_alerts clip ends"
        )
        if self.state.full_image_version != FULL_IMAGE_VERSION:
            self.hass.async_create_background_task(
                self._async_reset_full_images(), "security_alerts review images"
            )

    @callback
    def add_unsub(self, unsub: CALLBACK_TYPE) -> None:
        """Keep a listener to remove on stop."""
        self._unsubs.append(unsub)

    async def async_stop(self, *_: Any) -> None:
        for unsub in self._unsubs:
            unsub()
        self._unsubs.clear()
        if self._expiry_unsub:
            self._expiry_unsub()
            self._expiry_unsub = None
        for cancel in self._render_timers.values():
            cancel()
        self._render_timers.clear()
        await self.hass.async_add_executor_job(self.log.close)

    async def _async_prune(self, *_: Any) -> None:
        try:
            dropped = await self.hass.async_add_executor_job(
                self.log.prune, self.config[CONF_LOG_DAYS]
            )
        except AlertLogError:
            return  # Already logged; tried again tomorrow.
        if dropped:
            _LOGGER.info("Pruned %d old security alerts", dropped)

    async def _async_fill_missing_clip_ends(self, *_: Any) -> None:
        """Give a 60 s clip to alerts whose end or OFF never arrived."""
        try:
            await self.hass.async_add_executor_job(
                self.log.fill_missing_clip_ends,
                time.time() - CLIP_MISSING_END_SECONDS,
                # The clip starts CLIP_PRE_SECONDS before the event.
                CLIP_PRE_SECONDS + CLIP_FALLBACK_LENGTH_SECONDS,
            )
        except AlertLogError:
            return  # Already logged; tried again in 5 minutes.

    async def _async_reset_full_images(self) -> None:
        """Delete the review images an older version cached, once; each renders again."""
        try:
            deleted = await self.hass.async_add_executor_job(self.log.delete_variant_media, FULL)
        except AlertLogError:
            return  # Already logged; tried again on the next start.
        self.state.full_image_version = FULL_IMAGE_VERSION
        self.state.save()
        _LOGGER.info("Deleted %d review images cached by an older version", deleted)

    # Facts

    def _is_on(self, entity_id: str) -> bool:
        state = self.hass.states.get(entity_id)
        return state is not None and state.state == STATE_ON

    def mode(self, override: str | None = None) -> Mode | None:
        if override is None:
            return active_mode(self.modes, self._is_on)
        if override.casefold() == HOME.casefold():
            return None
        for mode in self.modes:
            if mode.name.casefold() == override.casefold():
                return mode
        raise ServiceValidationError(f"Unknown mode: {override}")

    def asleep(self) -> bool:
        state = self.hass.states.get(self.config[CONF_SLEEP_ENTITY])
        return is_asleep(state.state if state else None, self.config[CONF_SLEEP_THRESHOLD])

    def night(self, at: dt_time | None = None) -> bool:
        now = at or dt_util.now().time()
        return is_night(now, self.config[CONF_NIGHT_START], self.config[CONF_NIGHT_END])

    def quiet_after_restart(self) -> bool:
        entity = self.config.get(CONF_QUIET_AFTER_RESTART_ENTITY)
        return bool(entity) and self._is_on(entity)

    def is_top_floor(self, entity_id: str) -> bool:
        """A sensor is top floor when its area (entity, else device) is on a top floor."""
        entry = er.async_get(self.hass).async_get(entity_id)
        if entry is None:
            return False
        area_id = entry.area_id
        if not area_id and entry.device_id:
            device = dr.async_get(self.hass).async_get(entry.device_id)
            area_id = device.area_id if device else None
        if not area_id:
            return False
        area = ar.async_get(self.hass).async_get_area(area_id)
        return area is not None and area.floor_id in self.top_floors

    def _camera_state(self, camera: str) -> State | None:
        """The Frigate camera entity whose `camera_name` is `camera`."""
        for state in self.hass.states.async_all("camera"):
            if state.attributes.get("camera_name") == camera:
                return state
        return None

    def camera_entity(self, camera: str) -> str | None:
        state = self._camera_state(camera)
        return state.entity_id if state else None

    def camera_name(self, camera: str) -> str:
        state = self._camera_state(camera)
        if state and state.attributes.get("friendly_name"):
            return str(state.attributes["friendly_name"])
        return camera.replace("_", " ").title()

    def sensor_name(self, entity_id: str) -> str:
        state = self.hass.states.get(entity_id)
        if state and state.attributes.get("friendly_name"):
            return str(state.attributes["friendly_name"])
        return entity_id.split(".", 1)[-1].replace("_", " ").capitalize()

    # Quiet entries

    def running_quiet(self) -> list[QuietEntry]:
        self._drop_expired()
        return list(self._quiet)

    @callback
    def _drop_expired(self) -> None:
        now = time.time()
        still = running(self._quiet, now)
        if len(still) != len(self._quiet):
            self._quiet = still
            self._quiet_changed()

    @callback
    def _quiet_changed(self) -> None:
        self.state.quiet = [e.as_dict() for e in self._quiet]
        self.state.save()
        self._schedule_expiry()
        async_dispatcher_send(self.hass, SIGNAL_QUIET_UPDATED)

    @callback
    def _schedule_expiry(self) -> None:
        if self._expiry_unsub:
            self._expiry_unsub()
            self._expiry_unsub = None
        when = next_expiry(self._quiet, time.time())
        if when is None:
            return

        @callback
        def _expired(_now: Any) -> None:
            self._expiry_unsub = None
            self._drop_expired()

        self._expiry_unsub = async_track_point_in_utc_time(
            self.hass, _expired, dt_util.utc_from_timestamp(when)
        )

    def add_quiet(
        self, kind: str, types: list[str], cameras: list[str], hours: float
    ) -> list[QuietEntry]:
        try:
            entries = new_entries(kind, types, cameras, hours, time.time(), _new_id)
        except ValueError as err:
            raise ServiceValidationError(str(err)) from err
        self._quiet = [*running(self._quiet, time.time()), *entries]
        self._quiet_changed()
        return entries

    def end_quiet(self, entry_id: str) -> bool:
        before = len(self._quiet)
        self._quiet = [e for e in self._quiet if e.id != entry_id]
        if len(self._quiet) == before:
            return False
        self._quiet_changed()
        return True

    def end_all_quiet(self) -> int:
        count = len(running(self._quiet, time.time()))
        if self._quiet:
            self._quiet = []
            self._quiet_changed()
        return count

    # Decisions

    def _decide(
        self, event: AlertEvent, overrides: Overrides | None, record: bool
    ) -> tuple[Decision, str, float]:
        """Decide one event; with `record`, a ring restarts the burst window at once.

        Synchronous, so two events of one type are always decided in order.
        """
        overrides = overrides or Overrides()
        mode = self.mode(overrides.mode)
        asleep = self.asleep() if overrides.asleep is None else overrides.asleep
        base = base_level(
            event.kind,
            mode=mode,
            home=self.home,
            top_floor=event.top_floor,
            asleep=asleep,
            night=self.night(overrides.at),
        )
        mode_name = mode.name if mode else HOME
        now = time.time()
        decision = decide(
            base=base,
            mode_name=mode_name,
            event_type=event.type,
            camera=event.camera,
            quiet_entries=self.running_quiet(),
            quiet_after_restart=self.quiet_after_restart(),
            burst=self.burst,
            now=now,
        )
        if record and decision.rings:
            self.burst.record(event.type, now)
            self._save_rings()
        return decision, mode_name, now

    @callback
    def _save_rings(self) -> None:
        self.state.last_rings = self.burst.as_dict()
        self.state.save()

    async def async_handle(
        self, event: AlertEvent, *, notify: bool = True, overrides: Overrides | None = None
    ) -> tuple[Decision, str | None]:
        """Decide, log, render and send one event; return the decision and the log row id.

        `notify` False only decides: nothing is logged, sent or recorded.
        """
        decision, mode_name, decided_at = self._decide(event, overrides, record=notify)
        _LOGGER.info(
            "%s %s from %s: %s (%s)%s",
            event.kind,
            event.type,
            event.source,
            decision.delivery,
            decision.reason,
            "" if notify else " [simulated, not sent]",
        )
        if not notify or not decision.is_alert:
            return decision, None

        # Images are fetched in parallel, but the sends of one type keep the
        # order of the decisions: a popup repeat never lands before its ring.
        previous_send = self._sends.get(event.type)
        this_send: asyncio.Future[None] = self.hass.loop.create_future()
        self._sends[event.type] = this_send
        alert_id = _new_id()
        sent = False
        try:
            await self._async_log(event, decision, mode_name, alert_id)
            thumb = await self._async_store_thumbnail(event, decision, alert_id)
            if decision.is_sent:
                if previous_send is not None:
                    await previous_send
                sent = await self._async_send(event, decision, alert_id, thumb is not None)
        finally:
            if decision.rings and not sent:
                # The ring never went out, so the next critical alert should ring.
                self.burst.forget(event.type, decided_at)
                self._save_rings()
            this_send.set_result(None)
            if self._sends.get(event.type) is this_send:
                del self._sends[event.type]
        return decision, alert_id

    async def _async_log(
        self, event: AlertEvent, decision: Decision, mode_name: str, alert_id: str
    ) -> None:
        """Write the log row first, so a review started now already includes it."""
        row = AlertRow(
            id=alert_id,
            time=event.time,
            kind=event.kind,
            type=event.type,
            source=event.source,
            name=event.name,
            delivery=decision.delivery,
            mode=mode_name,
            action=event.action,
            event_id=event.event_id,
            snapshot_time=event.snapshot_time,
            snapshot_box=event.snapshot_box,
            clip_start=event.clip_start,
            clip_end=event.clip_end,
        )
        try:
            event.time = await self.hass.async_add_executor_job(self.log.insert, row)
        except AlertLogError:
            return  # Already logged; the phone still gets the alert.
        async_dispatcher_send(self.hass, SIGNAL_ALERT_LOGGED, row)

    async def _async_store_thumbnail(
        self, event: AlertEvent, decision: Decision, alert_id: str
    ) -> bytes | None:
        """Fetch and save the notification image, only when the alert is sent.

        The review view shows no picture for a sound, and renders a detection's
        own review image from the recording.
        """
        if not decision.is_sent:
            return None
        snapshot_before = event.snapshot_time
        thumb = await self._async_thumbnail(event)
        try:
            if thumb is not None:
                await self.hass.async_add_executor_job(self.log.write_media, alert_id, THUMB, thumb)
            if event.snapshot_box is not None and event.snapshot_time != snapshot_before:
                await self.hass.async_add_executor_job(
                    self.log.update_snapshot, alert_id, event.snapshot_time, event.snapshot_box
                )
        except AlertLogError:
            pass  # Already logged; the notification can still carry the image.
        return thumb

    async def _async_send(
        self, event: AlertEvent, decision: Decision, alert_id: str, has_image: bool
    ) -> bool:
        title, message = alert_text(event.kind, event.type, event.name, event.action, event.time)
        payload = alert_payload(
            alert_id=alert_id,
            kind=event.kind,
            event_type=event.type,
            title=title,
            message=message,
            delivery=decision.delivery,
            has_image=has_image,
        )
        if not await self.notifier.async_send(payload):
            return False
        self._remember_tag(payload["data"]["tag"])
        return True

    @callback
    def _remember_tag(self, tag: str) -> None:
        if tag not in self.state.shown_tags:
            self.state.shown_tags.append(tag)
            self.state.save()

    # Images

    async def _async_thumbnail(self, event: AlertEvent) -> bytes | None:
        """The notification image, or None: an alert without one still goes out."""
        try:
            if event.kind == SOUND and event.camera:
                return await self.frigate.latest(event.camera)
            if event.kind == DETECTION and event.camera:
                return await self._async_detection_thumbnail(event)
        except (FrigateError, imaging.ImageRenderError) as err:
            _LOGGER.warning("No image for %s %s: %s", event.type, event.source, err)
        return None

    async def _async_detection_thumbnail(self, event: AlertEvent) -> bytes | None:
        """The MQTT box on Frigate's snapshot, else the event API's box, else Frigate's crop."""
        assert event.camera is not None
        label = type_name(event.type)
        if event.event_id is None:
            # Simulated: the live frame with the given box.
            frame = await self.frigate.latest(event.camera)
            if event.snapshot_box is None:
                return frame
            detect_size = self.frigate.detect_size(event.camera)
            return await self._async_render_thumb(frame, event.snapshot_box, label, detect_size)
        frame, frame_time = await self.frigate.event_snapshot(event.event_id)
        known: tuple[float, Box] | None = None
        if frame_time is not None and self.find_snapshot is not None:
            box = await self.find_snapshot(
                event.event_id, frame_time, SNAPSHOT_MATCH_TIMEOUT_SECONDS
            )
            if box is not None:
                event.snapshot_time, event.snapshot_box = frame_time, box
                known = (frame_time, box)
        try:
            snapshot = await self._async_pair(
                event.camera, event.event_id, frame, frame_time, known
            )
        except FrigateError as err:
            _LOGGER.debug("No event box for %s: %s", event.event_id, err)
            snapshot = None
        if snapshot is not None:
            return await self._async_render_thumb(snapshot.frame, snapshot.box, label)
        _LOGGER.debug("No box for %s at %s; using Frigate's crop", event.event_id, frame_time)
        return await self.frigate.event_snapshot_cropped(event.event_id)

    async def _async_render_thumb(
        self, frame: bytes, box: Box, label: str, box_size: Size | None = None
    ) -> bytes:
        """The thumbnail around `box`, given in `box_size` pixels (default: the frame's)."""

        def render() -> bytes:
            size = imaging.image_size(frame)
            scaled = scale_box(box, box_size or size, size)
            return imaging.render_crop(frame, thumbnail_crop(scaled, size), scaled, label)

        return await self.hass.async_add_executor_job(render)

    async def _async_pair(
        self,
        camera: str,
        event_id: str,
        frame: bytes,
        frame_time: float | None,
        known: tuple[float, Box] | None,
    ) -> _Snapshot | None:
        """Pair Frigate's clean event snapshot with the box drawn on that very frame.

        `known` is a frame time and a detect-resolution box, from MQTT or the log
        row: it is the snapshot's box when its time is the snapshot's. Otherwise the
        event API's box is, when its time is. None when neither is.

        Raises:
            FrigateError: the event API failed.
            imaging.ImageRenderError: the snapshot is not an image.
        """
        if frame_time is None:
            return None
        size = await self.hass.async_add_executor_job(imaging.image_size, frame)
        if known is not None and abs(known[0] - frame_time) < FRAME_TIME_TOLERANCE:
            box = scale_box(known[1], self.frigate.detect_size(camera) or size, size)
            return _Snapshot(frame, size, frame_time, box)
        box = _event_box(await self.frigate.event(event_id), frame_time, size)
        return None if box is None else _Snapshot(frame, size, frame_time, box)

    async def async_full_image(self, alert_id: str) -> bytes | None:
        """The review image: rendered once, at most one render at a time, then cached.

        Raises:
            AlertLogError: the log or the image directory failed.
        """
        row = await self.hass.async_add_executor_job(self.log.get, alert_id)
        if row is None:
            return None
        cached = await self.hass.async_add_executor_job(self.log.read_media, alert_id, FULL)
        if cached is not None:
            return cached
        if row.kind == SOUND:
            return await self.hass.async_add_executor_job(self.log.read_media, alert_id, THUMB)
        if row.kind != DETECTION:
            return None
        async with self._media_lock(alert_id, FULL):
            # Another request may have rendered it while this one waited.
            cached = await self.hass.async_add_executor_job(self.log.read_media, alert_id, FULL)
            if cached is not None:
                return cached
            snapshot = await self._async_review_snapshot(row)
            if snapshot is not None and not self.match_ready(snapshot.frame_time, time.time()):
                # A match on a recording that is not saved yet could miss the frame and
                # stick, so a fallback shows, uncached, until it is.
                return await self._async_full_fallback(row, snapshot)
            image = await self._async_render_full(row, snapshot)
            if image is not None:
                await self.hass.async_add_executor_job(self.log.write_media, alert_id, FULL, image)
                return image
            image = await self._async_full_fallback(row, snapshot)
            if image is not None and time.time() - row.time > FULL_FALLBACK_CACHE_AFTER_SECONDS:
                await self.hass.async_add_executor_job(self.log.write_media, alert_id, FULL, image)
            return image

    async def _async_review_snapshot(self, row: AlertRow) -> _Snapshot | None:
        """A detection's event snapshot and box; None for a simulated one, or on failure."""
        if row.event_id is None:
            return None
        known = None
        if row.snapshot_time is not None and row.snapshot_box is not None:
            known = (row.snapshot_time, row.snapshot_box)
        try:
            frame, frame_time = await self.frigate.event_snapshot(row.event_id)
            return await self._async_pair(row.source, row.event_id, frame, frame_time, known)
        except (FrigateError, imaging.ImageRenderError) as err:
            _LOGGER.debug("No event snapshot for %s: %s", row.id, err)
            return None

    async def _async_render_full(self, row: AlertRow, snapshot: _Snapshot | None) -> bytes | None:
        """The recording frame the snapshot shows, at full resolution, with box and label."""
        if snapshot is None:
            return None
        label = type_name(row.type)
        async with self._match_slots:
            try:
                clip = await self.frigate.recording_clip(
                    row.source,
                    snapshot.frame_time - MATCH_WINDOW_SECONDS,
                    snapshot.frame_time + MATCH_WINDOW_SECONDS,
                )
            except FrigateError as err:
                _LOGGER.debug("No recording clip for %s: %s", row.id, err)
                return None

            def render() -> bytes | None:
                found = matching.best_frame(
                    clip, matching.FrameMatcher(snapshot.frame, snapshot.box)
                )
                if found is None:
                    return None
                frame, _ = found
                box = scale_box(snapshot.box, snapshot.size, frame.size)
                return imaging.render_frame(frame, box, label)

            try:
                image = await self.hass.async_add_executor_job(render)
            except matching.MatchError as err:
                _LOGGER.debug("Could not match the recording of %s: %s", row.id, err)
                return None
        if image is None:
            _LOGGER.debug("No recording frame of %s matches its snapshot", row.id)
        return image

    async def _async_full_fallback(self, row: AlertRow, snapshot: _Snapshot | None) -> bytes | None:
        """The detect snapshot with its box, else Frigate's boxed snapshot, else the thumbnail."""
        if snapshot is not None:
            try:
                return await self.hass.async_add_executor_job(
                    imaging.render_full, snapshot.frame, snapshot.box, type_name(row.type)
                )
            except imaging.ImageRenderError as err:
                _LOGGER.warning("Could not render the review image of %s: %s", row.id, err)
        if row.event_id:
            try:
                return await self.frigate.event_snapshot_boxed(row.event_id)
            except FrigateError as err:
                _LOGGER.debug("No Frigate snapshot for %s: %s", row.id, err)
        return await self.hass.async_add_executor_job(self.log.read_media, row.id, THUMB)

    # Audio

    async def async_audio(self, alert_id: str) -> Path | None:
        """A sound's audio clip: cut from Frigate's clip on the first request, then cached.

        Returns None when the alert is missing, is not a sound, or its clip is not ready.

        Raises:
            AlertLogError: the log or the media directory failed.
            AudioClipError: ffmpeg failed, timed out or wrote an empty file.
        """
        row = await self.async_get(alert_id)
        if row is None or row.kind != SOUND:
            return None
        window = self.clip_window(row)
        if window is None or not self.clip_ready(window, time.time()):
            return None
        async with self._media_lock(alert_id, AUDIO):
            if not await self.hass.async_add_executor_job(self.log.has_media, alert_id, AUDIO):
                await self._async_cut_audio(row.source, window, alert_id)
        return self.log.media_path(alert_id, AUDIO)

    @contextlib.asynccontextmanager
    async def _media_lock(self, alert_id: str, variant: str) -> AsyncIterator[None]:
        """At most one render or ffmpeg run per alert and variant at a time."""
        key = (alert_id, variant)
        entry = self._media_locks.setdefault(key, _MediaLock())
        entry.users += 1
        try:
            async with entry.lock:
                yield
        finally:
            entry.users -= 1
            if not entry.users:
                del self._media_locks[key]

    async def _async_cut_audio(self, camera: str, window: tuple[int, int], alert_id: str) -> None:
        """Copy the audio of Frigate's clip, without re-encoding, into the media directory.

        Raises:
            AlertLogError: the media directory failed.
            AudioClipError: ffmpeg failed, timed out or wrote an empty file.
        """
        try:
            url = self.frigate.clip_url(camera, *window)
        except FrigateError as err:
            raise AudioClipError(str(err)) from err
        tmp = self.log.media_tmp_path(alert_id, AUDIO)
        kept = False
        try:
            # No video, the audio copied as is, and the index first so playback
            # can start (and seek) before the whole file has loaded.
            await _async_ffmpeg(
                *("-i", url, "-vn", "-c:a", "copy", "-movflags", "+faststart"),
                *("-f", "mp4", str(tmp)),
            )
            kept = await self.hass.async_add_executor_job(self.log.keep_media_tmp, alert_id, AUDIO)
        finally:
            if not kept:
                await self.hass.async_add_executor_job(self.log.drop_media_tmp, alert_id, AUDIO)
        if not kept:
            raise AudioClipError("ffmpeg wrote an empty file")

    # Event entry points (called by Sources)

    async def async_detection(
        self,
        *,
        camera: str,
        label: str,
        event_id: str,
        start_time: float,
        snapshot: tuple[float, Box] | None,
    ) -> None:
        self._pending_ends[event_id] = _PendingEnd()
        try:
            event = AlertEvent(
                kind=DETECTION,
                type=label,
                source=camera,
                name=self.camera_name(camera),
                time=time.time(),
                camera=camera,
                event_id=event_id,
                snapshot_time=snapshot[0] if snapshot else None,
                snapshot_box=snapshot[1] if snapshot else None,
                clip_start=start_time - CLIP_PRE_SECONDS,
            )
            await self.async_handle(event)
        finally:
            pending = self._pending_ends.pop(event_id, None)
        if pending is not None and (pending.end is not None or pending.snapshot is not None):
            await self._async_apply_end(event_id, pending.end, pending.snapshot)

    async def async_detection_ended(
        self, event_id: str, end_time: float | None, snapshot: tuple[float, Box] | None
    ) -> None:
        pending = self._pending_ends.get(event_id)
        if pending is not None:
            pending.end, pending.snapshot = end_time, snapshot
            return
        await self._async_apply_end(event_id, end_time, snapshot)

    async def _async_apply_end(
        self, event_id: str, end_time: float | None, snapshot: tuple[float, Box] | None
    ) -> None:
        """Fill a detection's clip end and final snapshot (a newer box drops the cached
        review image), and render its review image once the recording is saved."""
        try:
            row = await self.hass.async_add_executor_job(self.log.by_event_id, event_id)
            if row is None:
                return
            if end_time is not None:
                await self.hass.async_add_executor_job(
                    self.log.update_clip_end, row.id, end_time + CLIP_POST_SECONDS
                )
            if snapshot is not None and snapshot[0] != row.snapshot_time:
                await self.hass.async_add_executor_job(
                    self.log.update_snapshot, row.id, snapshot[0], snapshot[1]
                )
                await self.hass.async_add_executor_job(self.log.delete_media, row.id, FULL)
        except AlertLogError:
            return  # Already logged; the 30-minute fallback still gives a clip.
        if end_time is not None:
            self._schedule_render(row.id, end_time + CLIP_POST_SECONDS + CLIP_READY_DELAY_SECONDS)

    @callback
    def _schedule_render(self, alert_id: str, when: float) -> None:
        """Render a review image in the background at `when`, so the review list has it
        ready; one not rendered by then renders on its first view."""
        if (cancel := self._render_timers.pop(alert_id, None)) is not None:
            cancel()

        @callback
        def _render(_now: Any) -> None:
            self._render_timers.pop(alert_id, None)
            self.hass.async_create_background_task(
                self._async_prerender(alert_id), "security_alerts review image"
            )

        self._render_timers[alert_id] = async_track_point_in_utc_time(
            self.hass, _render, dt_util.utc_from_timestamp(when)
        )

    async def _async_prerender(self, alert_id: str) -> None:
        with contextlib.suppress(AlertLogError):  # Already logged; it renders on view.
            await self.async_full_image(alert_id)

    async def async_sound(self, camera: str, label: str, when: float) -> None:
        key = (camera, label)
        self._active_sounds[key] = None
        self._pending_offs.pop(key, None)
        event = AlertEvent(
            kind=SOUND,
            type=label,
            source=camera,
            name=self.camera_name(camera),
            time=when,
            camera=camera,
            clip_start=when - CLIP_PRE_SECONDS,
        )
        _, alert_id = await self.async_handle(event)
        if alert_id is None:
            self._active_sounds.pop(key, None)
            self._pending_offs.pop(key, None)
            return
        self._active_sounds[key] = alert_id
        if (off := self._pending_offs.pop(key, None)) is not None:
            await self.async_sound_ended(camera, label, off)

    async def async_sound_ended(self, camera: str, label: str, when: float) -> None:
        key = (camera, label)
        if key not in self._active_sounds:
            return
        row_id = self._active_sounds[key]
        if row_id is None:
            self._pending_offs[key] = when
            return
        del self._active_sounds[key]
        try:
            await self.hass.async_add_executor_job(
                self.log.update_clip_end, row_id, when + CLIP_POST_SECONDS
            )
        except AlertLogError:
            pass  # Already logged; the 30-minute fallback still gives a clip.

    async def async_sensor(self, kind: str, entity_id: str, action: str | None) -> None:
        event = AlertEvent(
            kind=kind,
            type=kind,
            source=entity_id,
            name=self.sensor_name(entity_id),
            time=time.time(),
            top_floor=self.is_top_floor(entity_id),
            action=action,
        )
        await self.async_handle(event)

    # Review

    def review_start_default(self, now: float) -> float:
        if self.state.last_review is not None:
            return self.state.last_review
        return now - self.config[CONF_FIRST_REVIEW_HOURS] * 3600

    async def async_review_start(self) -> tuple[float, float, list[AlertRow], bool]:
        """Record a review: return everything since the last one, and clear the panel."""
        now = time.time()
        start = self.review_start_default(now)
        self.state.last_review = now
        tags, self.state.shown_tags = self.state.shown_tags, []
        self.state.save()
        rows, more = await self.async_window(start, now)
        self.hass.async_create_background_task(
            self.notifier.async_clear(tags), "security_alerts clear notifications"
        )
        return start, now, rows, more

    async def async_window(
        self, start: float, end: float, after: tuple[float, str] | None = None
    ) -> tuple[list[AlertRow], bool]:
        """One page of a review window, newest first, and whether more follow."""
        return await self.hass.async_add_executor_job(
            self.log.window, start, end, REVIEW_PAGE_SIZE, after
        )

    async def async_get(self, alert_id: str) -> AlertRow | None:
        return await self.hass.async_add_executor_job(self.log.get, alert_id)

    # Actions

    async def async_trigger_siren(self, *, notify_phone: bool) -> tuple[bool, str]:
        siren = self.config.get(CONF_SIREN_ENTITY)
        if siren:
            await self.hass.services.async_call(
                "siren", "turn_on", {"entity_id": siren}, blocking=True
            )
            return True, "Siren triggered"
        if notify_phone and await self.notifier.async_send(siren_missing_payload()):
            self._remember_tag(SIREN_TAG)
        return False, "No siren is set up"

    async def async_snooze_from_notification(self, event_type: str) -> None:
        entries = self.add_quiet(SNOOZE, [event_type], [], SNOOZE_ACTION_HOURS)
        await self.notifier.async_send(snoozed_payload(event_type, entries[0].ends_at))

    async def async_simulate(
        self,
        *,
        kind: str,
        event_type: str | None,
        camera: str | None,
        entity_id: str | None,
        action: str | None,
        seconds: float | None,
        box: Box | None,
        overrides: Overrides,
        notify: bool,
    ) -> dict[str, Any]:
        now = time.time()
        if kind in (DETECTION, SOUND):
            if not camera or not event_type:
                raise ServiceValidationError("A detection or sound needs a camera and a type")
            event = AlertEvent(
                kind=kind,
                type=event_type,
                source=camera,
                name=self.camera_name(camera),
                time=now,
                camera=camera,
                clip_start=now - CLIP_PRE_SECONDS,
                clip_end=now + CLIP_FALLBACK_LENGTH_SECONDS,
            )
            if kind == DETECTION:
                event.snapshot_time = now
                event.snapshot_box = box or self._default_box(camera)
        else:
            if not entity_id:
                raise ServiceValidationError("A door or motion event needs an entity_id")
            if kind == MOTION and seconds is not None and seconds <= self.motion_min_seconds:
                return {
                    "delivery": NONE,
                    "reason": f"motion lasted {seconds:g} s, not more than "
                    f"{self.motion_min_seconds:g} s",
                    "top_floor": self.is_top_floor(entity_id),
                }
            event = AlertEvent(
                kind=kind,
                type=kind,
                source=entity_id,
                name=self.sensor_name(entity_id),
                time=now,
                top_floor=self.is_top_floor(entity_id),
                action=(action or "opened") if kind == DOOR else None,
            )
        decision, _ = await self.async_handle(event, notify=notify, overrides=overrides)
        return {
            "delivery": decision.delivery,
            "base": decision.base,
            "reason": decision.reason,
            "top_floor": event.top_floor,
            "type": event.type,
            "type_name": type_name(event.type),
        }

    def _default_box(self, camera: str) -> Box:
        width, height = self.frigate.detect_size(camera) or (640, 360)
        return (width * 0.4, height * 0.25, width * 0.6, height * 0.75)

    def clip_window(self, row: AlertRow) -> tuple[int, int] | None:
        if row.clip_start is None or row.clip_end is None:
            return None
        return math.floor(row.clip_start), math.ceil(row.clip_end)

    @staticmethod
    def clip_ready(window: tuple[int, int], now: float) -> bool:
        """A clip counts as ready once its recording should be saved."""
        return now >= window[1] + CLIP_READY_DELAY_SECONDS

    @staticmethod
    def match_ready(frame_time: float, now: float) -> bool:
        """The recording a snapshot is matched against counts as saved, like a clip's."""
        return now >= frame_time + MATCH_WINDOW_SECONDS + CLIP_READY_DELAY_SECONDS
