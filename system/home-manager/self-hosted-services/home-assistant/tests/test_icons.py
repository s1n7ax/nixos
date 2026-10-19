from __future__ import annotations

import pytest

from core.icons import FALLBACK_ICONS, TYPE_ICONS, icon_for
from core.policy import DETECTION, DOOR, MOTION, SOUND


@pytest.mark.parametrize(
    ("kind", "event_type", "icon"),
    [
        (DETECTION, "person", "mdi:human"),
        (DETECTION, "car", "mdi:car"),
        (DETECTION, "motorcycle", "mdi:motorbike"),
        (DETECTION, "umbrella", "mdi:umbrella"),
        (SOUND, "bark", "mdi:dog-side"),
        (SOUND, "fire_alarm", "mdi:fire-alert"),
        (SOUND, "scream", "mdi:account-alert"),
        (SOUND, "yell", "mdi:account-voice"),
        (SOUND, "speech", "mdi:account-tie-voice"),
        (DOOR, DOOR, "mdi:door"),
        (MOTION, MOTION, "mdi:motion-sensor"),
    ],
)
def test_each_listed_type_has_its_own_icon(kind, event_type, icon):
    assert icon_for(kind, event_type) == icon


def test_no_two_types_share_an_icon():
    icons = [*TYPE_ICONS.values(), *FALLBACK_ICONS.values()]
    assert len(set(icons)) == len(icons)


def test_unknown_detection_gets_the_generic_camera_icon():
    assert icon_for(DETECTION, "kangaroo") == "mdi:cctv"


def test_unknown_sound_gets_the_generic_sound_icon():
    assert icon_for(SOUND, "glass_breaking") == "mdi:waveform"


def test_unknown_kind_raises():
    with pytest.raises(ValueError):
        icon_for("smoke", "smoke")
