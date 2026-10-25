"""Frame matching on a synthetic clip: a patterned square moving across a patterned scene."""

from __future__ import annotations

import random
from io import BytesIO

import av
import pytest
from PIL import Image, ImageChops, ImageStat

from core.geometry import scale_box
from matching import COMPARE_SIZE, EDGE_SECONDS, MAX_BOX_SCORE, FrameMatcher, MatchError, best_frame

CLIP_SIZE = (640, 360)
# The snapshot is smaller than the recording, like a detect stream.
SNAPSHOT_SIZE = (320, 180)
FPS = 10
FRAMES = 20
SIDE = 60


def blocks(seed: int, size: tuple[int, int], cell: int) -> Image.Image:
    """Random grey blocks, coarse enough to survive the matcher's blur."""
    rng = random.Random(seed)
    grid = Image.new("L", (size[0] // cell, size[1] // cell))
    grid.putdata([rng.randrange(40, 216) for _ in range(grid.width * grid.height)])
    return grid.resize(size, Image.Resampling.NEAREST)


SCENE = blocks(1, CLIP_SIZE, 20)
OBJECT = blocks(2, (SIDE, SIDE), 15)
OTHER_OBJECT = blocks(3, (SIDE, SIDE), 15)


def square_at(index: int) -> tuple[int, int, int, int]:
    """Where the square is in frame `index`, in clip pixels."""
    x = 20 + index * 28
    return (x, 150, x + SIDE, 150 + SIDE)


def picture(square=None, item=OBJECT) -> Image.Image:
    image = SCENE.copy()
    if square is not None:
        image.paste(item, square[:2])
    return image.convert("RGB")


def encode_clip() -> bytes:
    out = BytesIO()
    with av.open(out, mode="w", format="mp4") as container:
        stream = container.add_stream("mpeg4", rate=FPS)
        stream.width, stream.height = CLIP_SIZE
        stream.pix_fmt = "yuv420p"
        stream.options = {"qscale": "2"}
        for index in range(FRAMES):
            frame = av.VideoFrame.from_image(picture(square_at(index)))
            container.mux(stream.encode(frame))
        container.mux(stream.encode())
    return out.getvalue()


def jpeg(image: Image.Image) -> bytes:
    out = BytesIO()
    image.save(out, format="JPEG", quality=95)
    return out.getvalue()


def snapshot_of(image: Image.Image) -> bytes:
    return jpeg(image.resize(SNAPSHOT_SIZE))


def to_snapshot(box):
    return scale_box(box, CLIP_SIZE, SNAPSHOT_SIZE)


def frames(item=OBJECT) -> list[tuple[float, Image.Image, int]]:
    """The clip's frames as FrameMatcher.pick takes them, with their index as payload."""
    return [
        (index / FPS, picture(square_at(index), item).convert("L").resize(COMPARE_SIZE), index)
        for index in range(FRAMES)
    ]


def mean_difference(a: Image.Image, b: Image.Image) -> float:
    return ImageStat.Stat(ImageChops.difference(a.convert("L"), b.convert("L"))).mean[0]


@pytest.fixture(scope="module")
def clip():
    return encode_clip()


@pytest.mark.parametrize("index", [7, 12])
def test_returns_the_frame_the_snapshot_shows_at_full_resolution(clip, index):
    square = square_at(index)
    matcher = FrameMatcher(snapshot_of(picture(square)), to_snapshot(square))
    found = best_frame(clip, matcher)
    assert found is not None
    image, score = found
    assert image.size == CLIP_SIZE
    assert image.mode == "RGB"
    assert score <= MAX_BOX_SCORE
    # The square is where the snapshot has it, not where a neighbouring frame does.
    expected = mean_difference(image, picture(square))
    assert expected < mean_difference(image, picture(square_at(index - 1)))
    assert expected < mean_difference(image, picture(square_at(index + 1)))


def test_matches_through_exposure_contrast_and_a_small_offset():
    index = 9
    square = square_at(index)
    # Washed out and brighter, and two pixels lower: how a detect stream can differ.
    shown = picture(square).point(lambda v: 110 + v // 2)
    shown = ImageChops.offset(shown, 0, 2)
    found = FrameMatcher(snapshot_of(shown), to_snapshot(square)).pick(frames())
    assert found is not None
    assert found[0] == index


def test_a_closest_frame_whose_box_differs_returns_nothing():
    # The clip's square has another pattern: frame 9 is the closest, as the scene around
    # the box matches, but what is in the box is not the snapshot's object.
    square = square_at(9)
    matcher = FrameMatcher(snapshot_of(picture(square)), to_snapshot(square))
    clip_frames = frames(OTHER_OBJECT)
    scores = [matcher.score(frame) for _, frame, _ in clip_frames]
    assert scores.index(min(scores)) == 9
    assert matcher.pick(clip_frames) is None


@pytest.mark.parametrize("index", [0, FRAMES - 1])
def test_a_best_frame_at_either_end_of_the_clip_returns_nothing(index):
    # The snapshot's moment may lie beyond the clip there.
    square = square_at(index)
    matcher = FrameMatcher(snapshot_of(picture(square)), to_snapshot(square))
    assert matcher.pick(frames()) is None


def test_a_frame_just_inside_the_edge_is_kept():
    index = round(EDGE_SECONDS * FPS)
    square = square_at(index)
    matcher = FrameMatcher(snapshot_of(picture(square)), to_snapshot(square))
    found = matcher.pick(frames())
    assert found is not None
    assert found[0] == index


def test_no_frames_returns_nothing():
    matcher = FrameMatcher(snapshot_of(picture(square_at(5))), to_snapshot(square_at(5)))
    assert matcher.pick([]) is None


def test_a_box_on_the_edge_still_compares():
    scene = picture()
    matcher = FrameMatcher(snapshot_of(scene), (300, 170, 320, 180))
    small = scene.convert("L").resize(COMPARE_SIZE)
    assert matcher.score(small) < 0.1
    assert matcher.box_score(small) < 0.1


@pytest.mark.parametrize("data", [b"", b"not a clip"])
def test_unreadable_clips_raise_match_error(data):
    matcher = FrameMatcher(snapshot_of(picture()), (10, 10, 50, 50))
    with pytest.raises(MatchError):
        best_frame(data, matcher)


def test_unreadable_snapshot_raises_match_error():
    with pytest.raises(MatchError):
        FrameMatcher(b"not a jpeg", (10, 10, 50, 50))
