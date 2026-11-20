"""What a light was last set to, and how a turn-on that leaves it out gets it back.

Pure Python, no Home Assistant imports, so the tests run without it.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

# A light's brightness and colour, keyed like `light.turn_on`'s own data, e.g.
# {"brightness": 127, "color_temp_kelvin": 4000}. Stored as JSON, so colours may come back as lists.
Setting = dict[str, Any]

BRIGHTNESS = "brightness"
WHITE = "white"
# The attribute that holds a light's colour in each colour mode.
COLOR_BY_MODE = {
    "color_temp": "color_temp_kelvin",
    "hs": "hs_color",
    "rgb": "rgb_color",
    "rgbw": "rgbw_color",
    "rgbww": "rgbww_color",
    "xy": "xy_color",
}
# Every colour a turn-on can carry once Home Assistant has resolved it: `kelvin`, `color_name`
# and the like have already become one of these.
COLOR_KEYS = (*COLOR_BY_MODE.values(), WHITE)


def setting(attributes: Mapping[str, Any]) -> Setting | None:
    """The brightness and colour of a light that is on, or None when it reports neither."""
    remembered: Setting = {}
    if (brightness := attributes.get(BRIGHTNESS)) is not None:
        remembered[BRIGHTNESS] = int(brightness)
    key = COLOR_BY_MODE.get(attributes.get("color_mode"))
    if key is not None and (color := attributes.get(key)) is not None:
        remembered[key] = list(color) if isinstance(color, (list, tuple)) else color
    return remembered or None


def fill(params: dict[str, Any], remembered: Setting | None) -> dict[str, Any]:
    """The turn-on's params with the remembered brightness and colour where it gave none.

    What the turn-on asks for wins: a brightness keeps the remembered colour, a colour keeps the
    remembered brightness. `white` sets both, so it takes nothing.
    """
    filled = dict(params)
    if not remembered or WHITE in filled:
        return filled
    if BRIGHTNESS in remembered:
        filled.setdefault(BRIGHTNESS, remembered[BRIGHTNESS])
    if not any(key in filled for key in COLOR_KEYS):
        for key in COLOR_BY_MODE.values():
            if key in remembered:
                color = remembered[key]
                filled[key] = tuple(color) if isinstance(color, list) else color
    return filled
