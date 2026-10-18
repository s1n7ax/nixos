"""Rendering on synthetic frames: a green object on grey, with a known box."""

from __future__ import annotations

from io import BytesIO

import pytest
from PIL import Image

from core.geometry import scale_box, thumbnail_crop
from imaging import (
    BOX_COLOR,
    THUMB_SIZE,
    ImageRenderError,
    image_size,
    render_crop,
    render_full,
)

FRAME = (640, 360)
GREY = (90, 90, 90)
GREEN = (0, 200, 0)


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
    thumb = decode(render_crop(frame_with_object(box), crop, box))
    assert thumb.size == THUMB_SIZE
    w, h = THUMB_SIZE
    # The box centre is the image centre, and the object is there.
    assert close(thumb.getpixel((w // 2, h // 2)), GREEN)
    # The box outline is drawn in the box colour somewhere in the image.
    reds = sum(1 for px in thumb.get_flattened_data() if close(px, BOX_COLOR))
    assert reds > 100


def test_thumbnail_pads_outside_the_frame_with_black():
    box = (0, 0, 60, 60)
    thumb = decode(render_crop(frame_with_object(box), thumbnail_crop(box, FRAME), box))
    assert close(thumb.getpixel((2, 2)), (0, 0, 0), tolerance=20)


def test_render_full_draws_the_scaled_box_on_a_larger_frame():
    detect_box = (100, 100, 200, 300)
    big = (1280, 720)
    box = scale_box(detect_box, FRAME, big)
    out = decode(render_full(frame_with_object(box, big), box))
    assert out.size == big
    x1, y1, x2, y2 = (round(v) for v in box)
    assert close(out.getpixel((x1 + 1, (y1 + y2) // 2)), BOX_COLOR)
    assert close(out.getpixel(((x1 + x2) // 2, (y1 + y2) // 2)), GREEN)


def test_render_full_without_box_returns_the_frame():
    jpeg = frame_with_object((10, 10, 20, 20))
    assert render_full(jpeg, None) is jpeg


def test_empty_crop_raises():
    with pytest.raises(ImageRenderError):
        render_crop(frame_with_object((10, 10, 20, 20)), (5, 5, 5, 5), (10, 10, 20, 20))


@pytest.mark.parametrize("data", [b"", b"not a jpeg", b"\xff\xd8\xff\xe0" + b"\x00" * 20])
def test_unreadable_frames_raise_image_render_error(data):
    with pytest.raises(ImageRenderError):
        image_size(data)
    with pytest.raises(ImageRenderError):
        render_full(data, (1, 1, 2, 2))
    with pytest.raises(ImageRenderError):
        render_crop(data, (0, 0, 10, 5), (1, 1, 2, 2))
