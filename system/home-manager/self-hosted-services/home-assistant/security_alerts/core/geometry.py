"""Crop rectangles for notification thumbnails and box scaling.

Boxes and rectangles are (x1, y1, x2, y2) in pixels; sizes are (width, height).

The companion app uses one image as the square collapsed thumbnail, the round
Android Auto thumbnail and the expanded picture. So the thumbnail is 2:1,
centred on the box, and tall enough that the box's diagonal fits inside the
circle inscribed in the centred square: the whole box survives every shape.
"""

from __future__ import annotations

import math

Box = tuple[float, float, float, float]
Size = tuple[int, int]

THUMB_ASPECT = 2.0
# The circle's diameter is this many times the box diagonal.
THUMB_MARGIN = 1.1
# A small object is not blown up beyond this share of the frame height.
THUMB_MIN_HEIGHT_FRACTION = 0.25


def _check_size(size: Size) -> None:
    if size[0] <= 0 or size[1] <= 0:
        raise ValueError(f"Invalid image size: {size}")


def thumbnail_crop(box: Box, frame: Size) -> Box:
    """Return the 2:1 crop rectangle around `box`; it may reach outside the frame."""
    _check_size(frame)
    x1, y1, x2, y2 = box
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    diagonal = math.hypot(x2 - x1, y2 - y1)
    height = max(diagonal * THUMB_MARGIN, frame[1] * THUMB_MIN_HEIGHT_FRACTION)
    width = height * THUMB_ASPECT
    return (cx - width / 2, cy - height / 2, cx + width / 2, cy + height / 2)


def scale_box(box: Box, from_size: Size, to_size: Size) -> Box:
    """Scale a box from one image size to another (detect resolution to a frame)."""
    _check_size(from_size)
    _check_size(to_size)
    sx = to_size[0] / from_size[0]
    sy = to_size[1] / from_size[1]
    x1, y1, x2, y2 = box
    return (x1 * sx, y1 * sy, x2 * sx, y2 * sy)


def map_box(box: Box, crop: Box, out_size: Size) -> Box:
    """Return where `box` lands in an image made by resizing `crop` to `out_size`."""
    _check_size(out_size)
    cx1, cy1, cx2, cy2 = crop
    sx = out_size[0] / (cx2 - cx1)
    sy = out_size[1] / (cy2 - cy1)
    x1, y1, x2, y2 = box
    return ((x1 - cx1) * sx, (y1 - cy1) * sy, (x2 - cx1) * sx, (y2 - cy1) * sy)
