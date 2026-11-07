"""Rendering on synthetic frames: a green object on grey, with a known box and label."""

from __future__ import annotations

from io import BytesIO

import pytest
from PIL import Image

from core.geometry import map_box, scale_box, thumbnail_crop
from imaging import (
    BOX_COLOR,
    LABEL_COLOR,
    THUMB_SIZE,
    ImageRenderError,
    image_size,
    render_crop,
    render_frame,
    render_full,
)

FRAME = (640, 360)
GREY = (90, 90, 90)
GREEN = (0, 200, 0)
LABEL = "Person"


def frame_with_object(box, size=FRAME):
    image = Image.new("RGB", size, GREY)
    x1, y1, x2, y2 = (round(v) for v in box)
    image.paste(GREEN, (x1, y1, x2, y2))
    out = BytesIO()
    image.save(out, format="JPEG", quality=95)
    return out.getvalue()


def decode(jpeg):
    return Image.open(BytesIO(jpeg)).convert("RGB")


def close(a, b, tolerance=60):
    return all(abs(x - y) <= tolerance for x, y in zip(a, b, strict=True))


def count(image, colour, area):
    """How many pixels of `area` (x1, y1, x2, y2) are close to `colour`."""
    x1, y1, x2, y2 = (round(v) for v in area)
    return sum(
        1 for x in range(x1, x2) for y in range(y1, y2) if close(image.getpixel((x, y)), colour)
    )


def has_label(image, area):
    """A filled tab in the box colour with white text on it covers most of `area`."""
    x1, y1, x2, y2 = (round(v) for v in area)
    size = (x2 - x1) * (y2 - y1)
    return count(image, BOX_COLOR, area) > size / 3 and count(image, LABEL_COLOR, area) > 10


def test_image_size():
    assert image_size(frame_with_object((10, 10, 20, 20))) == FRAME


@pytest.mark.parametrize(
    "box",
    [
        pytest.param((300, 130, 340, 330), id="tall-centre"),
        pytest.param((0, 100, 200, 160), id="wide-left-edge"),
        pytest.param((560, 280, 640, 360), id="bottom-right-corner"),
    ],
)
def test_thumbnail_keeps_the_object_and_its_box(box):
    crop = thumbnail_crop(box, FRAME)
    thumb = decode(render_crop(frame_with_object(box), crop, box, LABEL))
    assert thumb.size == THUMB_SIZE
    w, h = THUMB_SIZE
    # The box centre is the image centre, and the object is there.
    assert close(thumb.getpixel((w // 2, h // 2)), GREEN)
    # The box outline is drawn in the box colour somewhere in the image.
    reds = sum(1 for px in thumb.get_flattened_data() if close(px, BOX_COLOR))
    assert reds > 100


def test_thumbnail_pads_outside_the_frame_with_black():
    box = (0, 0, 60, 60)
    thumb = decode(render_crop(frame_with_object(box), thumbnail_crop(box, FRAME), box, LABEL))
    assert close(thumb.getpixel((2, 2)), (0, 0, 0), tolerance=20)


def test_render_full_draws_the_scaled_box_on_a_larger_frame():
    detect_box = (100, 100, 200, 300)
    big = (1280, 720)
    box = scale_box(detect_box, FRAME, big)
    out = decode(render_full(frame_with_object(box, big), box, LABEL))
    assert out.size == big
    x1, y1, x2, y2 = (round(v) for v in box)
    assert close(out.getpixel((x1 + 1, (y1 + y2) // 2)), BOX_COLOR)
    assert close(out.getpixel(((x1 + x2) // 2, (y1 + y2) // 2)), GREEN)


def test_render_full_without_box_returns_the_frame():
    jpeg = frame_with_object((10, 10, 20, 20))
    assert render_full(jpeg, None, LABEL) is jpeg


BIG = (1280, 720)
# The label's text is 1/30 of the image height: 24 px here.
TEXT = 24


def test_render_full_draws_the_label_above_the_box():
    box = (400, 300, 520, 600)
    out = decode(render_full(frame_with_object(box, BIG), box, LABEL))
    x1, y1 = box[0], box[1]
    assert has_label(out, (x1, y1 - TEXT, x1 + 2 * TEXT, y1))
    # The tab starts at the box's left edge, and nothing is drawn further up.
    assert count(out, BOX_COLOR, (x1 - 20, y1 - TEXT, x1 - 2, y1)) == 0
    assert count(out, BOX_COLOR, (x1, y1 - 3 * TEXT, x1 + 2 * TEXT, y1 - 2 * TEXT)) == 0


def test_render_full_draws_the_label_inside_a_box_on_the_top_edge():
    box = (400, 0, 520, 300)
    out = decode(render_full(frame_with_object(box, BIG), box, LABEL))
    # Inside the box, along its top edge, past the box's own outline.
    assert has_label(out, (box[0] + 6, 6, box[0] + 2 * TEXT, TEXT))
    assert close(out.getpixel(((box[0] + box[2]) // 2, 150)), GREEN)


def test_render_full_keeps_the_label_inside_the_image_on_the_right():
    box = (1240, 300, 1280, 400)
    out = decode(render_full(frame_with_object(box, BIG), box, LABEL))
    # The tab ends at the right edge instead of being cut off.
    assert has_label(out, (BIG[0] - 2 * TEXT, box[1] - TEXT, BIG[0], box[1]))


def test_render_frame_draws_box_and_label_on_a_decoded_frame():
    box = (400, 300, 520, 600)
    frame = decode(frame_with_object(box, BIG))
    out = decode(render_frame(frame, box, LABEL))
    assert out.size == BIG
    assert close(out.getpixel((box[0] + 1, 450)), BOX_COLOR)
    assert has_label(out, (box[0], box[1] - TEXT, box[0] + 2 * TEXT, box[1]))


# The label's text is 1/20 of the thumbnail height.
THUMB_TEXT = THUMB_SIZE[1] // 20


def test_thumbnail_draws_the_label_above_a_wide_box():
    box = (200, 160, 440, 220)
    crop = thumbnail_crop(box, FRAME)
    thumb = decode(render_crop(frame_with_object(box), crop, box, LABEL))
    x1, y1, _, _ = map_box(box, crop, THUMB_SIZE)
    assert has_label(thumb, (x1, y1 - THUMB_TEXT, x1 + 2 * THUMB_TEXT, y1))


def test_thumbnail_draws_the_label_inside_a_tall_box():
    # A tall box fills the thumbnail's height: no room above it.
    box = (300, 130, 340, 330)
    crop = thumbnail_crop(box, FRAME)
    thumb = decode(render_crop(frame_with_object(box), crop, box, LABEL))
    x1, y1, _, _ = map_box(box, crop, THUMB_SIZE)
    assert has_label(thumb, (x1 + 6, y1 + 6, x1 + 2 * THUMB_TEXT, y1 + THUMB_TEXT))


def test_empty_crop_raises():
    with pytest.raises(ImageRenderError):
        render_crop(frame_with_object((10, 10, 20, 20)), (5, 5, 5, 5), (10, 10, 20, 20), LABEL)


@pytest.mark.parametrize("data", [b"", b"not a jpeg", b"\xff\xd8\xff\xe0" + b"\x00" * 20])
def test_unreadable_frames_raise_image_render_error(data):
    with pytest.raises(ImageRenderError):
        image_size(data)
    with pytest.raises(ImageRenderError):
        render_full(data, (1, 1, 2, 2), LABEL)
    with pytest.raises(ImageRenderError):
        render_crop(data, (0, 0, 10, 5), (1, 1, 2, 2), LABEL)
