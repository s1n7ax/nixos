"""House model: serves the 3D house dashboard card and loads it on dashboards.

Set up from a bare `house_model:` line in configuration.yaml. The card holds no data;
it reads the house from Home Assistant's states. Use it as the only card of a panel
view: `type: custom:house-dashboard-card`.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from homeassistant.components import frontend
from homeassistant.components.http import StaticPathConfig
from homeassistant.components.lovelace.const import LOVELACE_DATA, MODE_STORAGE
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType

DOMAIN = "house_model"
FRONTEND_URL = "/house_model_frontend"
FRONTEND_DIR = Path(__file__).parent / "frontend"
CARD_FILE = "house-dashboard-card.js"


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    if DOMAIN not in config:
        return True
    version = await hass.async_add_executor_job(_version)
    # No long cache: the card imports its modules without a version, so the browser
    # must revalidate them after a deploy.
    await hass.http.async_register_static_paths(
        [StaticPathConfig(FRONTEND_URL, str(FRONTEND_DIR), cache_headers=False)]
    )
    await _async_load_card(hass, f"{FRONTEND_URL}/{CARD_FILE}?v={version}")
    return True


def _version() -> str:
    """A digest of every frontend file, so any change reloads the card."""
    digest = hashlib.sha256()
    for path in sorted(FRONTEND_DIR.rglob("*.js")):
        digest.update(path.read_bytes())
    return digest.hexdigest()[:12]


async def _async_load_card(hass: HomeAssistant, url: str) -> None:
    """Load the card from the dashboard resources, kept at this version.

    A resource and not an extra JS URL: an extra JS URL runs at page load, racing the
    frontend's swap of `window.customElements`, and a card defined before it is lost.
    """
    lovelace = hass.data[LOVELACE_DATA]
    if lovelace.resource_mode != MODE_STORAGE:
        frontend.add_extra_js_url(hass, url)
        return
    resources = lovelace.resources
    await resources.async_get_info()  # Loads the collection from storage.
    path = url.partition("?")[0]
    item = next((i for i in resources.async_items() if i["url"].partition("?")[0] == path), None)
    if item is None:
        await resources.async_create_item({"res_type": "module", "url": url})
    elif item["url"] != url or item["type"] != "module":
        await resources.async_update_item(item["id"], {"res_type": "module", "url": url})
