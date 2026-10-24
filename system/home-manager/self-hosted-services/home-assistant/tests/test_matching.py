"""Frame matching on a synthetic clip: a white square moving across a grey frame."""

from __future__ import annotations

from io import BytesIO

import av
import pytest
from PIL import Image

from core.geometry import scale_box
from matching import MAX_SCORE, FrameMatcher, MatchError, best_frame

CLIP_SIZE = (640, 360)
# The snapshot is smaller than the recording, like a detect stream.
SNAPSHOT_SIZE = (320, 180)
FRAMES = 20
SIDE = 60
GREY = (90, 90, 90)
WHITE = (255, 255, 255)


def square_at(index: int) -> tuple[int, int, int, int]:
    """Where the square is in frame `index`, in clip pixels."""
    x = 20 + index * 28
    return (x, 150, x + SIDE, 150 + SIDE)


def picture(size, square=None, background=GREY) -> Image.Image:
    image = Image.new("RGB", size, background)
    if square is not None:
        image.paste(WHITE, square)
    return image


def encode_clip() -> bytes:
    out = BytesIO()
    with av.open(out, mode="w", format="mp4") as container:
        stream = container.add_stream("mpeg4", rate=10)
        stream.width, stream.height = CLIP_SIZE
        stream.pix_fmt = "yuv420p"
        stream.options = {"qscale": "2"}
        for index in range(FRAMES):
            frame = av.VideoFrame.from_image(picture(CLIP_SIZE, square_at(index)))
            container.mux(stream.encode(frame))
        container.mux(stream.encode())
    return out.getvalue()


def jpeg(image: Image.Image) -> bytes:
    out = BytesIO()
    image.save(out, format="JPEG", quality=95)
    return out.getvalue()


def to_snapshot(box):
    return scale_box(box, CLIP_SIZE, SNAPSHOT_SIZE)


@pytest.fixture(scope="module")
def clip():
    return encode_clip()


@pytest.mark.parametrize("index", [3, 11])
def test_returns_the_frame_the_snapshot_shows_at_full_resolution(clip, index):
    square = square_at(index)
    box = to_snapshot(square)
    snapshot = jpeg(picture(CLIP_SIZE, square).resize(SNAPSHOT_SIZE))
    found = best_frame(clip, FrameMatcher(snapshot, box))
    assert found is not None
    image, score = found
    assert image.size == CLIP_SIZE
    assert image.mode == "RGB"
    assert score <= MAX_SCORE
    # The square is where the snapshot has it, not where a neighbouring frame does.
    x1, y1, x2, y2 = square
    assert min(image.getpixel(((x1 + x2) // 2, (y1 + y2) // 2))) > 200
    assert max(image.getpixel((x1 + 3, y1 - 10))) < 140
    neighbour = square_at(index + 1)
    assert max(image.getpixel((neighbour[2] - 3, (y1 + y2) // 2))) < 140


def test_no_frame_close_enough_returns_nothing(clip):
    square = square_at(5)
    snapshot = jpeg(picture(SNAPSHOT_SIZE, background=(0, 0, 0)))
    assert best_frame(clip, FrameMatcher(snapshot, to_snapshot(square))) is None


def test_a_box_on_the_edge_still_compares():
    snapshot = jpeg(picture(SNAPSHOT_SIZE))
    matcher = FrameMatcher(snapshot, (300, 170, 320, 180))
    assert matcher.score(Image.new("L", (320, 180), GREY[0])) < 5


@pytest.mark.parametrize("data", [b"", b"not a clip"])
def test_unreadable_clips_raise_match_error(data):
    matcher = FrameMatcher(jpeg(picture(SNAPSHOT_SIZE)), (10, 10, 50, 50))
    with pytest.raises(MatchError):
        best_frame(data, matcher)


def test_unreadable_snapshot_raises_match_error():
    with pytest.raises(MatchError):
        FrameMatcher(b"not a jpeg", (10, 10, 50, 50))
