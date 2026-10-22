"""Login-only image and audio views for notifications and the review page."""

from __future__ import annotations

import logging

from aiohttp import web
from homeassistant.components.http import HomeAssistantView

from .const import AUDIO, FULL, THUMB
from .pipeline import AudioClipError, SecurityAlerts
from .store import AlertLogError

_LOGGER = logging.getLogger(__name__)

CACHE = {
    THUMB: "private, max-age=86400",
    FULL: "private, max-age=600",
    AUDIO: "private, max-age=86400",
}


class ImageView(HomeAssistantView):
    """`/api/security_alerts/image/<alert_id>/thumb.jpg` and `.../full.jpg`.

    The companion app sends its token for these relative URLs; the review page
    gets them signed over the logged-in websocket.
    """

    url = "/api/security_alerts/image/{alert_id:[0-9a-f]{32}}/{variant:(thumb|full)}.jpg"
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
            else:
                image = await self._alerts.async_full_image(alert_id)
        except AlertLogError:
            return web.Response(status=500)  # Already logged.
        if image is None:
            return web.Response(status=404)
        return web.Response(
            body=image, content_type="image/jpeg", headers={"Cache-Control": CACHE[variant]}
        )


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
