"""Find the recording frame a detection snapshot shows.

Frigate detects on a camera's low-resolution sub-stream and records its main
stream, and the two are out of sync: the recording frame stamped with the
snapshot's time can be up to a couple of seconds away from it, so a box drawn
there misses a moving object. Instead, every frame of a short recording clip
around that time is compared with the snapshot, and the closest one is kept, at
the recording's full resolution.

The two streams also differ in exposure, contrast and detail, and can be a few
pixels out of register, so a plain difference mostly measures how busy the
scene is. Each compared patch is therefore blurred and scaled to zero mean and
unit standard deviation, and the best of a few small offsets counts. The frame
is picked by the patch around the box (the object and the background around
it). It is kept only when the box alone matches too, as the object has to be
there and not just the scene around it, and when it is not at either end of the
clip, where the snapshot's moment may lie beyond a clip cut short. A clip is only
matched when the recording covers its whole window (`covers`), as Frigate cuts a
clip short at a gap in the recording.

Takes JPEG and MP4 bytes and a box in snapshot pixels, so it has no imports
from the integration and runs in an executor thread. PyAV comes with Home
Assistant (its `stream` integration uses it), like Pillow.
"""

from __future__ import annotations

import math
from collections.abc import Iterable, Iterator
from io import BytesIO

import av
from PIL import Image, ImageChops, ImageFilter, ImageStat

Box = tuple[float, float, float, float]
Size = tuple[int, int]
Rect = tuple[int, int, int, int]

# Frames are compared in greyscale at this size, blurred by this radius.
COMPARE_SIZE: Size = (320, 180)
BLUR_RADIUS = 2
# The patch that picks the frame is the box grown by this share of its width and
# height on each side, so the object and the background around it both count.
REGION_GROWTH = 0.5
# Patches are also compared this many pixels off in each direction.
MAX_SHIFT = 1
# The picked frame's box may differ from the snapshot's by at most this much: the
# mean absolute difference of the scaled patches, in standard deviations. On real
# alerts, matching frames scored up to 0.23, and frames where the object had moved
# away or was gone mostly above 0.3. An object with little contrast to its
# background (in shade, against glare) can score as low as 0.2 when it is gone.
MAX_BOX_SCORE = 0.3
# The picked frame must be at least this far from either end of the clip. On real
# alerts, the matching frame was at least 1 s from both ends.
EDGE_SECONDS = 0.5
# Frigate cuts a clip short where its recording has a gap, and the snapshot's
# moment may be in the missing part, so the recording has to cover the clip's whole
# window. Neighbouring segments' times can be up to about 1 s apart without a frame
# missing; real gaps (restarts) were 22 s or more.
MAX_RECORDING_GAP = 1.2
DECODER_THREADS = 2
# Scaled patches are 8-bit images: mid-grey at the mean, this many grey levels per
# standard deviation. A flat patch counts as this much spread, to avoid dividing by 0.
_SPREAD = 32
_MIN_DEVIATION = 1.0
# What Pillow raises for bytes it cannot read as an image.
_READ_ERRORS = (OSError, ValueError, Image.DecompressionBombError)


class MatchError(ValueError):
    """The snapshot or the clip could not be decoded."""


def covers(segments: Iterable[tuple[float, float]], start: float, end: float) -> bool:
    """Whether recording segments, as (start, end) times, cover `start` to `end`.

    Gaps up to MAX_RECORDING_GAP, inside or at either end, do not count.
    """
    covered = start
    for segment_start, segment_end in sorted(segments):
        if segment_start - covered > MAX_RECORDING_GAP:
            return False
        covered = max(covered, segment_end)
    return end - covered <= MAX_RECORDING_GAP


def _rect(box: Box, size: Size, growth: float) -> Rect:
    """The box grown by `growth` at COMPARE_SIZE, clipped to it, at least one pixel each way."""
    sx = COMPARE_SIZE[0] / size[0]
    sy = COMPARE_SIZE[1] / size[1]
    x1, y1, x2, y2 = box[0] * sx, box[1] * sy, box[2] * sx, box[3] * sy
    gx, gy = (x2 - x1) * growth, (y2 - y1) * growth
    left = min(max(0, round(x1 - gx)), COMPARE_SIZE[0] - 1)
    top = min(max(0, round(y1 - gy)), COMPARE_SIZE[1] - 1)
    right = max(min(COMPARE_SIZE[0], round(x2 + gx)), left + 1)
    bottom = max(min(COMPARE_SIZE[1], round(y2 + gy)), top + 1)
    return left, top, right, bottom


def _blurred(image: Image.Image) -> Image.Image:
    return image.filter(ImageFilter.GaussianBlur(BLUR_RADIUS))


def _scaled(patch: Image.Image) -> Image.Image:
    """The patch at mid-grey mean and _SPREAD grey levels per standard deviation."""
    stat = ImageStat.Stat(patch)
    mean = stat.mean[0]
    factor = _SPREAD / max(stat.stddev[0], _MIN_DEVIATION)
    return patch.point([min(255, max(0, round(128 + (v - mean) * factor))) for v in range(256)])


class FrameMatcher:
    """Compares greyscale COMPARE_SIZE frames with the snapshot: lower scores are closer."""

    def __init__(self, snapshot: bytes, box: Box) -> None:
        """`box` is in the snapshot's pixels.

        Raises:
            MatchError: the snapshot is not an image Pillow can read.
        """
        try:
            with Image.open(BytesIO(snapshot)) as source:
                size = source.size
                reference = _blurred(source.convert("L").resize(COMPARE_SIZE))
        except _READ_ERRORS as err:
            raise MatchError(f"Cannot read the snapshot: {err}") from err
        self._region = _rect(box, size, REGION_GROWTH)
        self._box = _rect(box, size, 0)
        self._references = {
            rect: _scaled(reference.crop(rect)) for rect in (self._region, self._box)
        }

    def score(self, frame: Image.Image) -> float:
        """How far the frame is from the snapshot around the box."""
        return self._compare(_blurred(frame), self._region)

    def box_score(self, frame: Image.Image) -> float:
        """How far the frame is from the snapshot within the box."""
        return self._compare(_blurred(frame), self._box)

    def _compare(self, frame: Image.Image, rect: Rect) -> float:
        reference = self._references[rect]
        left, top, right, bottom = rect
        best = math.inf
        for dy in range(-MAX_SHIFT, MAX_SHIFT + 1):
            for dx in range(-MAX_SHIFT, MAX_SHIFT + 1):
                if not (
                    0 <= left + dx
                    and 0 <= top + dy
                    and right + dx <= COMPARE_SIZE[0]
                    and bottom + dy <= COMPARE_SIZE[1]
                ):
                    continue
                patch = _scaled(frame.crop((left + dx, top + dy, right + dx, bottom + dy)))
                difference = ImageStat.Stat(ImageChops.difference(patch, reference)).mean[0]
                best = min(best, difference / _SPREAD)
        return best

    def pick[T](self, frames: Iterable[tuple[float, Image.Image, T]]) -> tuple[T, float] | None:
        """Return the closest frame's payload and its box score.

        `frames` are (time in seconds, greyscale COMPARE_SIZE frame, payload) in time
        order. The first of equally close frames wins. Returns None when there are no
        frames, the closest one's box scores above MAX_BOX_SCORE, or it lies within
        EDGE_SECONDS of the first or the last frame.
        """
        best: tuple[float, float, Image.Image, T] | None = None
        first = last = 0.0
        for index, (time, frame, payload) in enumerate(frames):
            if index == 0:
                first = time
            last = time
            score = self.score(frame)
            if best is None or score < best[0]:
                best = (score, time, frame, payload)
        if best is None:
            return None
        _, time, frame, payload = best
        if min(time - first, last - time) < EDGE_SECONDS:
            return None
        box_score = self.box_score(frame)
        if box_score > MAX_BOX_SCORE:
            return None
        return payload, box_score


def _frames(
    container: av.container.InputContainer, stream: av.VideoStream
) -> Iterator[tuple[float, Image.Image, av.VideoFrame]]:
    """The clip's frames as (time, greyscale COMPARE_SIZE frame, decoded frame)."""
    rate = float(stream.average_rate or 1)
    for index, frame in enumerate(container.decode(stream)):
        small = frame.reformat(width=COMPARE_SIZE[0], height=COMPARE_SIZE[1], format="gray")
        time = frame.time if frame.time is not None else index / rate
        # Some PyAV versions give RGB even for a grey frame.
        yield time, small.to_image().convert("L"), frame


def best_frame(clip: bytes, matcher: FrameMatcher) -> tuple[Image.Image, float] | None:
    """Return the frame the snapshot shows, in RGB at full resolution, and its box score.

    Returns None when the clip has no video frames or no frame passes
    `FrameMatcher.pick`.

    Raises:
        MatchError: PyAV cannot open or decode the clip.
    """
    try:
        with av.open(BytesIO(clip)) as container:
            if not container.streams.video:
                return None
            stream = container.streams.video[0]
            stream.thread_type = "AUTO"
            stream.codec_context.thread_count = DECODER_THREADS
            found = matcher.pick(_frames(container, stream))
            if found is None:
                return None
            frame, score = found
            return frame.to_image().convert("RGB"), score
    except av.FFmpegError as err:
        raise MatchError(f"Cannot decode the clip: {err}") from err
