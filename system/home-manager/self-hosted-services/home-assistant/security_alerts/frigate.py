"""A small async client for the Frigate API, on Home Assistant's shared session.

The base URL comes from the Frigate integration's config entry.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

import aiohttp
from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.util.json import json_loads

FRIGATE_DOMAIN = "frigate"
TIMEOUT = aiohttp.ClientTimeout(total=15)


class FrigateError(Exception):
    """Frigate could not be reached or answered with an error."""


def _listen(camera: dict[str, Any]) -> list[str]:
    """The sound labels a camera listens for; none while its audio is off."""
    audio = camera.get("audio", {})
    return (audio.get("listen") or []) if audio.get("enabled") else []


class FrigateClient:
    def __init__(self, hass: HomeAssistant) -> None:
        self._hass = hass
        self.config: dict[str, Any] | None = None

    def _base_url(self) -> str:
        for entry in self._hass.config_entries.async_entries(FRIGATE_DOMAIN):
            if url := entry.data.get("url"):
                return str(url).rstrip("/")
        raise FrigateError("No Frigate integration is set up")

    async def _get(
        self, path: str, params: dict[str, Any] | None = None
    ) -> tuple[bytes, Mapping[str, str]]:
        session = async_get_clientsession(self._hass)
        url = f"{self._base_url()}/{path}"
        try:
            async with session.get(url, params=params, timeout=TIMEOUT) as response:
                if response.status != 200:
                    raise FrigateError(f"GET {path}: HTTP {response.status}")
                return await response.read(), response.headers
        except (aiohttp.ClientError, TimeoutError) as err:
            raise FrigateError(f"GET {path}: {err}") from err

    async def async_refresh_config(self) -> dict[str, Any]:
        body, _ = await self._get("api/config")
        try:
            config = json_loads(body)
        except ValueError as err:
            raise FrigateError(f"api/config is not JSON: {err}") from err
        if not isinstance(config, dict):
            raise FrigateError("api/config is not an object")
        self.config = config
        return config

    def _cameras(self) -> dict[str, Any]:
        return (self.config or {}).get("cameras", {})

    def _enabled_cameras(self) -> dict[str, Any]:
        return {name: cam for name, cam in self._cameras().items() if cam.get("enabled", True)}

    def camera_names(self) -> list[str]:
        return list(self._enabled_cameras())

    def detect_size(self, camera: str) -> tuple[int, int] | None:
        detect = self._cameras().get(camera, {}).get("detect", {})
        width, height = detect.get("width"), detect.get("height")
        if not width or not height:
            return None
        return int(width), int(height)

    def listens_for(self, camera: str, label: str) -> bool:
        return label in _listen(self._cameras().get(camera, {}))

    def object_labels(self) -> list[str]:
        cameras = self._enabled_cameras().values()
        tracked = (cam.get("objects", {}).get("track") or [] for cam in cameras)
        return list(dict.fromkeys(label for labels in tracked for label in labels))

    def sound_labels(self) -> list[str]:
        cameras = self._enabled_cameras().values()
        return list(dict.fromkeys(label for cam in cameras for label in _listen(cam)))

    async def event(self, event_id: str) -> dict[str, Any]:
        """The event as `api/events/<id>` gives it; its `data` holds the snapshot's box."""
        body, _ = await self._get(f"api/events/{event_id}")
        try:
            event = json_loads(body)
        except ValueError as err:
            raise FrigateError(f"api/events/{event_id} is not JSON: {err}") from err
        if not isinstance(event, dict):
            raise FrigateError(f"api/events/{event_id} is not an object")
        return event

    async def _event_snapshot(
        self, event_id: str, *, bbox: int, crop: int
    ) -> tuple[bytes, Mapping[str, str]]:
        return await self._get(
            f"api/events/{event_id}/snapshot.jpg",
            {"bbox": bbox, "crop": crop, "timestamp": 0, "quality": 100},
        )

    async def event_snapshot(self, event_id: str) -> tuple[bytes, float | None]:
        """The clean, full-frame event snapshot and the frame time it was taken at."""
        body, headers = await self._event_snapshot(event_id, bbox=0, crop=0)
        try:
            frame_time = float(headers.get("X-Frame-Time", ""))
        except ValueError:
            frame_time = None
        return body, frame_time

    async def event_snapshot_cropped(self, event_id: str) -> bytes:
        """Frigate's own crop with its box: the thumbnail fallback."""
        body, _ = await self._event_snapshot(event_id, bbox=1, crop=1)
        return body

    async def event_snapshot_boxed(self, event_id: str) -> bytes:
        """The full event snapshot with Frigate's box: the review image fallback."""
        body, _ = await self._event_snapshot(event_id, bbox=1, crop=0)
        return body

    async def latest(self, camera: str) -> bytes:
        body, _ = await self._get(f"api/{camera}/latest.jpg", {"quality": 100})
        return body

    def clip_url(self, camera: str, start: int, end: int) -> str:
        """The URL of a camera's recording from `start` to `end`, as one MP4.

        Raises:
            FrigateError: no Frigate integration is set up.
        """
        return f"{self._base_url()}/api/{camera}/start/{start}/end/{end}/clip.mp4"

    async def recording_clip(self, camera: str, start: float, end: float) -> bytes:
        """A camera's recording from `start` to `end`, as MP4 bytes."""
        body, _ = await self._get(f"api/{camera}/start/{start}/end/{end}/clip.mp4")
        return body

    async def recordings(self, camera: str, start: float, end: float) -> list[tuple[float, float]]:
        """The (start, end) times of a camera's recording segments that overlap `start` to `end`."""
        path = f"api/{camera}/recordings"
        body, _ = await self._get(path, {"after": start, "before": end})
        try:
            segments = json_loads(body)
        except ValueError as err:
            raise FrigateError(f"{path} is not JSON: {err}") from err
        if not isinstance(segments, list):
            raise FrigateError(f"{path} is not a list")
        try:
            return [(float(s["start_time"]), float(s["end_time"])) for s in segments]
        except (KeyError, TypeError, ValueError) as err:
            raise FrigateError(f"{path} has a segment without times: {err}") from err
