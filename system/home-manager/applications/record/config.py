"""Every constant the record pipeline is built from.

Nothing here is a flag or a module option: the destination asks for one `record`
command with nothing to configure by hand, so the circle, the monitor, the rates
and the two device names are settled values that live in one place.
"""

from __future__ import annotations

import os
from pathlib import Path

MONITOR = "DP-3"
"""The one output `wf-recorder` grabs. Single-monitor machine."""

SCREEN_WIDTH = 3440
SCREEN_HEIGHT = 1440

HYPRLAND_SCALE = 1.25
"""Hyprland dispatcher coordinates are logical; ffplay's -x/-y are physical."""

OUTPUT_FPS = 50
"""50, not 60: the camera's 25.04 fps divides into it exactly 2:1 (ticket 06)."""

CAMERA_WIDTH = 1024
CAMERA_HEIGHT = 576
"""Movie mode live view. Stills mode is 960x640 and powers the body off."""

CAMERA_RATE_MIN = 24.5
CAMERA_RATE_MAX = 25.5
"""FHD 25.00P measures 25.04. Outside this band the Movie rec quality menu moved."""

WARMUP_FRAMES = 60
"""~2.4 s at 25 fps. Clears the stale-geometry frames and measures the feed."""

CIRCLE_DIAMETER = 540
CIRCLE_MARGIN = 40
RING_WIDTH = 6
RING_COLOUR = "0x89b4fa"
MASK_FEATHER = 3

HUD_WIDTH = 340
"""The circle's inscribed square is 381 px; 340 is what was measured hidden."""

MIC_SOURCE = "alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo"
"""Pinned by name: bound to the default, a headset taking a call steals the take."""

BLOCKED_DESKTOP_PREFIX = "alsa_output.pci-0000_05_00.1.pro-output-"
"""The four GPU HDMI monitors: the only wrong fallthrough on this machine."""

MIX_WEIGHTS = "1 0.35"
"""Desktop audio ~9 dB under the mic on the one track YouTube reads."""

UNTITLED = "UNTITLED"
CONTAINER = "mkv"
"""mkv because the shutdown ladder ends in SIGKILL and mp4 loses its moov atom."""

TIMESTAMP_FORMAT = "%Y-%m-%d %H-%M-%S"

SIGINT_GRACE_SECONDS = 10.0
SIGTERM_GRACE_SECONDS = 3.0

THREAD_QUEUE_SIZE = 512
"""The default 8 logs `Thread message queue blocking` at 3440x1440 immediately."""


def output_dir() -> Path:
    """Where takes are written. `RECORD_OUTPUT_DIR` redirects it for a dry run."""
    override = os.environ.get("RECORD_OUTPUT_DIR")
    if override:
        return Path(override)
    return Path.home() / "Videos" / "Youtube" / "00 new"


def circle_position() -> tuple[int, int]:
    """Physical top-left of the composited circle: bottom-right, 40 px clear."""
    return (
        SCREEN_WIDTH - CIRCLE_DIAMETER - CIRCLE_MARGIN,
        SCREEN_HEIGHT - CIRCLE_DIAMETER - CIRCLE_MARGIN,
    )


def camera_crop() -> tuple[int, int, int, int]:
    """Centred square on the live-view frame, as `w, h, x, y`.

    Framing is adjusted by moving the camera, never in software, so the crop is
    fixed and centred on whatever the source geometry is.
    """
    side = min(CAMERA_WIDTH, CAMERA_HEIGHT)
    return side, side, (CAMERA_WIDTH - side) // 2, (CAMERA_HEIGHT - side) // 2


def ring_inner_size() -> int:
    """The camera is scaled to this and padded out to the ring colour."""
    return CIRCLE_DIAMETER - 2 * RING_WIDTH


def hud_size() -> tuple[int, int]:
    """Preview window in physical pixels, the screen's aspect at `HUD_WIDTH`."""
    height = round(HUD_WIDTH * SCREEN_HEIGHT / SCREEN_WIDTH)
    return HUD_WIDTH, height - (height % 2)


def hud_position() -> tuple[int, int]:
    """Physical top-left that centres the preview inside the circle."""
    circle_x, circle_y = circle_position()
    hud_width, hud_height = hud_size()
    return (
        circle_x + (CIRCLE_DIAMETER - hud_width) // 2,
        circle_y + (CIRCLE_DIAMETER - hud_height) // 2,
    )


def to_logical(value: int) -> int:
    """Physical pixels to the logical coordinates Hyprland's dispatcher wants."""
    return round(value / HYPRLAND_SCALE)
