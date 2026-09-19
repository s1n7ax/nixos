"""The R5's live view, and the warm-up burst preflight gates on.

`gphoto2 --capture-movie` emits concatenated baseline JPEGs with no container and no
timestamps. Two facts shape everything here. The stream is camera-paced and rock
steady — movie mode is 1024x576 at exactly the Movie rec quality rate — so the rate is
a constant to check, not a variable to track. And after any mode or `liveviewsize`
change the body emits one or two stale-geometry frames at the head of the next stream,
which ffmpeg's mjpeg demuxer locks onto unconditionally, silently encoding the whole
take at the wrong size. `-probesize` does not help; a throwaway warm-up does, which is
what this module reads.
"""

from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass

import config
import errors
import supervisor

SOI = b"\xff\xd8"
EOI = b"\xff\xd9"

_SOF_MARKERS = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
_STANDALONE = {0x01, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9}

SETTLE_FRACTION = 0.2
"""How much of the head to ignore when deciding what geometry the feed settled on."""

CHUNK = 65536


def jpeg_size(frame: bytes) -> tuple[int, int] | None:
    """`width, height` from a frame's start-of-frame header, walking the segments.

    Segments are walked rather than searched for `FF C0`, because an `FF` byte inside
    entropy-coded data is stuffed as `FF 00` and a naive search reads it as a marker.
    """
    index = 2
    while index + 3 < len(frame):
        if frame[index] != 0xFF:
            index += 1
            continue
        marker = frame[index + 1]
        if marker == 0xFF:
            index += 1
            continue
        if marker in _STANDALONE:
            index += 2
            continue
        length = int.from_bytes(frame[index + 2 : index + 4], "big")
        if marker in _SOF_MARKERS and index + 9 <= len(frame):
            height = int.from_bytes(frame[index + 5 : index + 7], "big")
            width = int.from_bytes(frame[index + 7 : index + 9], "big")
            return width, height
        if length < 2:
            return None
        index += 2 + length
    return None


def split_frames(buffer: bytes) -> tuple[list[bytes], bytes]:
    """Complete frames out of a read buffer, plus whatever is still partial."""
    frames = []
    start = buffer.find(SOI)
    while start != -1:
        end = buffer.find(EOI, start + 2)
        if end == -1:
            break
        frames.append(buffer[start : end + 2])
        start = buffer.find(SOI, end + 2)
    if start == -1:
        return frames, b""
    return frames, buffer[start:]


@dataclass(frozen=True)
class Probe:
    """What a warm-up burst says the camera is currently doing."""

    geometry: tuple[int, int] | None
    fps: float
    frames: int

    @classmethod
    def of(cls, sizes: list[tuple[int, int] | None], arrivals: list[float]) -> Probe:
        """Read the burst, ignoring the head where the stale-geometry frames live."""
        if not sizes:
            return cls(geometry=None, fps=0.0, frames=0)
        settled = max(1, int(len(sizes) * SETTLE_FRACTION))
        tail = [size for size in sizes[settled:] if size] or [size for size in sizes if size]
        geometry = max(set(tail), key=tail.count) if tail else None
        span = arrivals[-1] - arrivals[0] if len(arrivals) > 1 else 0.0
        fps = (len(arrivals) - 1) / span if span > 0 else 0.0
        return cls(geometry=geometry, fps=fps, frames=len(sizes))


def gate(probe: Probe) -> list[str]:
    """Why the take must not start. Empty means the feed is what the pipeline assumes.

    Checking is enough — preflight never drives the camera over PTP. Wrong geometry
    catches both stills mode and a `liveviewsize` that quartered the source, and the
    rate catches a Movie rec quality menu left on 50.00P.
    """
    problems = []
    expected = (config.CAMERA_WIDTH, config.CAMERA_HEIGHT)
    if probe.geometry is None:
        return ["no live-view frames arrived — is the camera on, awake and on the USB cable?"]
    if probe.geometry != expected:
        width, height = probe.geometry
        detail = f"live view is {width}x{height}, expected {expected[0]}x{expected[1]}"
        if (width, height) == (512, 288):
            problems.append(f"{detail} — set liveviewsize back to Large")
        elif (width, height) == (960, 640):
            problems.append(f"{detail} — the mode switch is on Photo, move it to Movie")
        else:
            problems.append(detail)
    if not config.CAMERA_RATE_MIN <= probe.fps <= config.CAMERA_RATE_MAX:
        problems.append(
            f"live view runs at {probe.fps:.1f} fps, expected "
            f"{config.CAMERA_RATE_MIN}-{config.CAMERA_RATE_MAX} — set Movie rec quality to FHD 25.00P"
        )
    return problems


def warm_up(argv: list[str], frames: int = config.WARMUP_FRAMES, timeout: float = 20.0) -> Probe:
    """Run a throwaway live-view burst and measure it.

    Headless and discarded: ffmpeg must never see the stale-geometry frames, and this
    same burst is what clears them, so the take's own stream starts uniform.

    Raises:
        ToolUnavailableError: `gphoto2` is absent or would not start.
    """
    try:
        process = subprocess.Popen(
            argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True
        )
    except OSError as error:
        raise errors.ToolUnavailableError(f"{argv[0]} would not run: {error}") from error
    sizes: list[tuple[int, int] | None] = []
    arrivals: list[float] = []
    buffer = b""
    deadline = time.monotonic() + timeout
    stream = process.stdout
    try:
        while stream and len(sizes) < frames and time.monotonic() < deadline:
            chunk = stream.read1(CHUNK)
            if not chunk:
                break
            now = time.monotonic()
            buffer += chunk
            complete, buffer = split_frames(buffer)
            for frame in complete:
                sizes.append(jpeg_size(frame))
                arrivals.append(now)
    finally:
        supervisor.reap(process)
    return Probe.of(sizes, arrivals)
