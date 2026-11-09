"""Login-only image, audio and clip views for notifications and the review page."""

from __future__ import annotations

import logging
import time

from aiohttp import web
from homeassistant.components.http import HomeAssistantView

from .const import AUDIO, CROP, FULL, THUMB
from .frigate import FrigateError
from .notify import download_name
from .pipeline import AudioClipError, SecurityAlerts
from .store import AlertLogError, AlertRow

_LOGGER = logging.getLogger(__name__)

CACHE = {
    THUMB: "private, max-age=86400",
    FULL: "private, max-age=600",
    # A tile cut from the detect snapshot is replaced once the review image renders.
    CROP: "private, max-age=600",
    AUDIO: "private, max-age=86400",
}
CLIP_CACHE = "private, max-age=86400"
CLIP_CHUNK_BYTES = 64 * 1024


def _attachment(row: AlertRow, extension: str) -> str:
    """A Content-Disposition that saves the file under the alert's camera, type and time.

    The companion app's downloads take their file name from it.
    """
    return f'attachment; filename="{download_name(row.name, row.type, row.time, extension)}"'


class ImageView(HomeAssistantView):
    """`/api/security_alerts/image/<alert_id>/thumb.jpg`, `.../full.jpg` and `.../crop.jpg`.

    The companion app sends its token for these relative URLs; the review page
    gets them signed over the logged-in websocket. `?download=1` saves the image
    as a named file.
    """

    url = "/api/security_alerts/image/{alert_id:[0-9a-f]{32}}/{variant:(thumb|full|crop)}.jpg"
    name = "api:security_alerts:image"
    requires_auth = True

    def __init__(self, alerts: SecurityAlerts) -> None:
        self._alerts = alerts

    async def get(self, request: web.Request, alert_id: str, variant: str) -> web.Response:
        try:
            if variant == THUMB:
                image = await self._alerts.hass.async_add_executor_job(
                    self._alerts.log.read_media, alert_id, THUMB
                )
            elif variant == CROP:
                image = await self._alerts.async_crop_image(alert_id)
            else:
                image = await self._alerts.async_full_image(alert_id)
            row = await self._alerts.async_get(alert_id) if "download" in request.query else None
        except AlertLogError:
            return web.Response(status=500)  # Already logged.
        if image is None:
            return web.Response(status=404)
        headers = {"Cache-Control": CACHE[variant]}
        if row is not None:
            headers["Content-Disposition"] = _attachment(row, "jpg")
        return web.Response(body=image, content_type="image/jpeg", headers=headers)


class AudioView(HomeAssistantView):
    """`/api/security_alerts/audio/<alert_id>.m4a`: a sound's audio, without the video.

    Cut from Frigate's clip on the first request once the clip is ready, then
    served from the cache. Byte ranges work, so the player can seek.
    """

    url = "/api/security_alerts/audio/{alert_id:[0-9a-f]{32}}.m4a"
    name = "api:security_alerts:audio"
    requires_auth = True

    def __init__(self, alerts: SecurityAlerts) -> None:
        self._alerts = alerts

    async def get(self, request: web.Request, alert_id: str) -> web.StreamResponse:
        try:
            path = await self._alerts.async_audio(alert_id)
        except AlertLogError:
            return web.Response(status=500)  # Already logged.
        except AudioClipError as err:
            # Nothing is cached, so the next request tries again.
            _LOGGER.warning("Could not cut the audio of alert %s: %s", alert_id, err)
            return web.Response(status=502)
        if path is None:
            return web.Response(status=404)
        return web.FileResponse(
            path, headers={"Content-Type": "audio/mp4", "Cache-Control": CACHE[AUDIO]}
        )


class ClipView(HomeAssistantView):
    """`/api/security_alerts/clip/<alert_id>.mp4`: an alert's clip, saved as a named file.

    Streamed from Frigate once the clip is ready. Playing it uses the Frigate
    integration's own clip URL, which can seek.
    """

    url = "/api/security_alerts/clip/{alert_id:[0-9a-f]{32}}.mp4"
    name = "api:security_alerts:clip"
    requires_auth = True

    def __init__(self, alerts: SecurityAlerts) -> None:
        self._alerts = alerts

    async def get(self, request: web.Request, alert_id: str) -> web.StreamResponse:
        try:
            row = await self._alerts.async_get(alert_id)
        except AlertLogError:
            return web.Response(status=500)  # Already logged.
        window = self._alerts.clip_window(row) if row is not None else None
        if row is None or window is None or not self._alerts.clip_ready(window, time.time()):
            return web.Response(status=404)
        response = web.StreamResponse(
            headers={
                "Content-Type": "video/mp4",
                "Content-Disposition": _attachment(row, "mp4"),
                "Cache-Control": CLIP_CACHE,
            }
        )
        try:
            async with self._alerts.frigate.stream_clip(row.source, *window) as clip:
                await response.prepare(request)
                async for chunk in clip.content.iter_chunked(CLIP_CHUNK_BYTES):
                    try:
                        await response.write(chunk)
                    except ConnectionResetError:
                        return response  # The download was stopped.
        except FrigateError as err:
            _LOGGER.warning("Could not send the clip of alert %s: %s", alert_id, err)
            if not response.prepared:
                return web.Response(status=502)
            # Drop the connection before the last chunk, so the download fails
            # instead of ending short.
            if request.transport is not None:
                request.transport.abort()
        return response
