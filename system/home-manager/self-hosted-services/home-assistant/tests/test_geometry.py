from __future__ import annotations

import math

import pytest

from core.geometry import map_box, scale_box, thumbnail_crop

FRAME = (640, 360)
OUT = (1024, 512)
EPS = 1e-6


def corners(box):
    x1, y1, x2, y2 = box
    return [(x1, y1), (x2, y1), (x1, y2), (x2, y2)]


def boxes():
    """Tall, wide and square boxes at the centre and touching each frame edge."""
    w, h = FRAME
    shapes = {"tall": (40, 200), "wide": (300, 60), "square": (90, 90), "tiny": (6, 10)}
    for name, (bw, bh) in shapes.items():
        positions = {
            "centre": ((w - bw) / 2, (h - bh) / 2),
            "left": (0, (h - bh) / 2),
            "right": (w - bw, (h - bh) / 2),
            "top": ((w - bw) / 2, 0),
            "bottom": ((w - bw) / 2, h - bh),
            "top-left": (0, 0),
            "bottom-right": (w - bw, h - bh),
        }
        for where, (x, y) in positions.items():
            yield pytest.param((x, y, x + bw, y + bh), id=f"{name}-{where}")
    yield pytest.param((0, 0, w, h), id="whole-frame")


@pytest.mark.parametrize("box", list(boxes()))
def test_box_inside_circle_of_centred_square(box):
    crop = thumbnail_crop(box, FRAME)
    mapped = map_box(box, crop, OUT)
    cx, cy = OUT[0] / 2, OUT[1] / 2
    radius = OUT[1] / 2
    for x, y in corners(mapped):
        assert math.hypot(x - cx, y - cy) <= radius + EPS


@pytest.mark.parametrize("box", list(boxes()))
def test_box_inside_the_image(box):
    mapped = map_box(box, thumbnail_crop(box, FRAME), OUT)
    for x, y in corners(mapped):
        assert -EPS <= x <= OUT[0] + EPS
        assert -EPS <= y <= OUT[1] + EPS


@pytest.mark.parametrize("box", list(boxes()))
def test_crop_is_two_to_one_and_centred(box):
    x1, y1, x2, y2 = thumbnail_crop(box, FRAME)
    assert (x2 - x1) == pytest.approx(2 * (y2 - y1))
    assert (x1 + x2) / 2 == pytest.approx((box[0] + box[2]) / 2)
    assert (y1 + y2) / 2 == pytest.approx((box[1] + box[3]) / 2)


def test_small_box_gets_a_quarter_of_the_frame_height():
    x1, y1, x2, y2 = thumbnail_crop((300, 170, 306, 180), FRAME)
    assert y2 - y1 == pytest.approx(FRAME[1] * 0.25)


def test_large_box_height_is_its_diagonal_with_margin():
    box = (100, 50, 400, 300)
    x1, y1, x2, y2 = thumbnail_crop(box, FRAME)
    assert y2 - y1 == pytest.approx(math.hypot(300, 250) * 1.1)


def test_scale_box():
    assert scale_box((10, 20, 30, 40), (640, 360), (2560, 1440)) == (40, 80, 120, 160)


@pytest.mark.parametrize("size", [(0, 360), (640, 0), (-1, 10)])
def test_invalid_sizes_raise(size):
    with pytest.raises(ValueError):
        thumbnail_crop((0, 0, 1, 1), size)
    with pytest.raises(ValueError):
        scale_box((0, 0, 1, 1), size, FRAME)
