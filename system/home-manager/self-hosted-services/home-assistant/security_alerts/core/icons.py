"""The icon each alert type shows on the phone."""

from __future__ import annotations

from .policy import DETECTION, DOOR, MOTION, SOUND

# Frigate object and sound labels, and the two sensor types.
TYPE_ICONS = {
    "person": "mdi:human",
    "car": "mdi:car",
    "motorcycle": "mdi:motorbike",
    "umbrella": "mdi:umbrella",
    "bark": "mdi:dog-side",
    "fire_alarm": "mdi:fire-alert",
    "scream": "mdi:account-alert",
    "yell": "mdi:account-voice",
    "speech": "mdi:account-tie-voice",
    DOOR: "mdi:door",
    MOTION: "mdi:motion-sensor",
}

# A camera type nobody has seen yet gets its kind's generic icon. Door and motion
# events are typed by their kind, so they are always in TYPE_ICONS.
FALLBACK_ICONS = {DETECTION: "mdi:cctv", SOUND: "mdi:waveform"}


def icon_for(kind: str, event_type: str) -> str:
    """Return the type's own icon, else the generic one for its kind."""
    if icon := TYPE_ICONS.get(event_type):
        return icon
    if icon := FALLBACK_ICONS.get(kind):
        return icon
    raise ValueError(f"No icon for a {kind} event of type {event_type}")
