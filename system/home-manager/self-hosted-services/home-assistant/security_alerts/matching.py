"""Find the recording frame a detection snapshot shows.

Frigate detects on a camera's low-resolution sub-stream and records its main
stream, and the two are out of sync: the recording frame stamped with the
snapshot's time can be up to a couple of seconds away from it, so a box drawn
there misses a moving object. Instead, every frame of a short recording clip
around that time is compared with the snapshot in the region around the box,
and the closest one is kept, at the recording's full resolution.

Takes JPEG and MP4 bytes and a box in snapshot pixels, so it has no imports
from the integration and runs in an executor thread. PyAV comes with Home
Assistant (its `stream` integration uses it), like Pillow.
"""

from __future__ import annotations

from io import BytesIO

import av
from PIL import Image, ImageChops, ImageStat

Box = tuple[float, float, float, float]
Size = tuple[int, int]

# Frames are compared in greyscale at this size.
COMPARE_SIZE: Size = (320, 180)
# The compared region is the box grown by this share of its width and height on
# each side, so the object and the background around it both have to match.
REGION_GROWTH = 0.5
# The best frame's mean absolute grey difference (0-255) must not be above this.
MAX_SCORE = 25.0
DECODER_THREADS = 2
# What Pillow raises for bytes it cannot read as an image.
_READ_ERRORS = (OSError, ValueError, Image.DecompressionBombError)


class MatchError(ValueError):
    """The snapshot or the clip could not be decoded."""


def _region(box: Box, size: Size) -> tuple[int, int, int, int]:
    """The grown box, at COMPARE_SIZE and clipped to it, at least one pixel wide and high."""
    sx = COMPARE_SIZE[0] / size[0]
    sy = COMPARE_SIZE[1] / size[1]
    x1, y1, x2, y2 = box[0] * sx, box[1] * sy, box[2] * sx, box[3] * sy
    gx, gy = (x2 - x1) * REGION_GROWTH, (y2 - y1) * REGION_GROWTH
    left = min(max(0, round(x1 - gx)), COMPARE_SIZE[0] - 1)
    top = min(max(0, round(y1 - gy)), COMPARE_SIZE[1] - 1)
    right = max(min(COMPARE_SIZE[0], round(x2 + gx)), left + 1)
    bottom = max(min(COMPARE_SIZE[1], round(y2 + gy)), top + 1)
    return left, top, right, bottom


class FrameMatcher:
    """Scores frames against the snapshot's region around the box: lower is closer."""

    def __init__(self, snapshot: bytes, box: Box) -> None:
        """`box` is in the snapshot's pixels.

        Raises:
            MatchError: the snapshot is not an image Pillow can read.
        """
        try:
            with Image.open(BytesIO(snapshot)) as source:
                self._region = _region(box, source.size)
                reference = source.convert("L").resize(COMPARE_SIZE)
        except _READ_ERRORS as err:
            raise MatchError(f"Cannot read the snapshot: {err}") from err
        self._reference = reference.crop(self._region)

    def score(self, frame: Image.Image) -> float:
        """The mean absolute difference of a greyscale COMPARE_SIZE frame in the region."""
        difference = ImageChops.difference(frame.crop(self._region), self._reference)
        return ImageStat.Stat(difference).mean[0]


def best_frame(clip: bytes, matcher: FrameMatcher) -> tuple[Image.Image, float] | None:
    """Return the clip's closest frame, in RGB at full resolution, and its score.

    The first of equally close frames wins. Returns None when the clip has no
    video frames or even the closest one scores above MAX_SCORE.

    Raises:
        MatchError: PyAV cannot open or decode the clip.
    """
    best: tuple[float, av.VideoFrame] | None = None
    try:
        with av.open(BytesIO(clip)) as container:
            if not container.streams.video:
                return None
            stream = container.streams.video[0]
            stream.thread_type = "AUTO"
            stream.codec_context.thread_count = DECODER_THREADS
            for frame in container.decode(stream):
                small = frame.reformat(
                    width=COMPARE_SIZE[0], height=COMPARE_SIZE[1], format="gray"
                ).to_image()
                # Some PyAV versions give RGB even for a grey frame.
                score = matcher.score(small.convert("L"))
                if best is None or score < best[0]:
                    best = (score, frame)
            if best is None or best[0] > MAX_SCORE:
                return None
            return best[1].to_image().convert("RGB"), best[0]
    except av.FFmpegError as err:
        raise MatchError(f"Cannot decode the clip: {err}") from err
