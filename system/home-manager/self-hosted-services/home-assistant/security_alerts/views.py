"""Login-only image views for notifications and the review page."""

from __future__ import annotations

from aiohttp import web
from homeassistant.components.http import HomeAssistantView

from .const import FULL, THUMB
from .pipeline import SecurityAlerts
from .store import AlertLogError

CACHE = {THUMB: "private, max-age=86400", FULL: "private, max-age=600"}


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
