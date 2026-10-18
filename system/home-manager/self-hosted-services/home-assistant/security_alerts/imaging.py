"""Pillow rendering of notification thumbnails and review images.

Takes JPEG bytes and rectangles already worked out by `core.geometry`, so it
has no imports from the integration and runs in an executor thread.
"""

from __future__ import annotations

import math
from io import BytesIO

from PIL import Image, ImageDraw

Box = tuple[float, float, float, float]
Size = tuple[int, int]

THUMB_SIZE: Size = (1024, 512)
THUMB_QUALITY = 90
FULL_QUALITY = 92
BOX_COLOR = (255, 40, 40)


def image_size(jpeg: bytes) -> Size:
    with Image.open(BytesIO(jpeg)) as image:
        return image.size


def _line_width(size: Size) -> int:
    return max(2, round(min(size) / 170))


def _draw_box(image: Image.Image, box: Box) -> None:
    ImageDraw.Draw(image).rectangle(
        [round(v) for v in box], outline=BOX_COLOR, width=_line_width(image.size)
    )


def _encode(image: Image.Image, quality: int) -> bytes:
    out = BytesIO()
    image.save(out, format="JPEG", quality=quality, optimize=True)
    return out.getvalue()


def render_crop(
    jpeg: bytes,
    crop: Box,
    box: Box,
    out_size: Size = THUMB_SIZE,
    quality: int = THUMB_QUALITY,
) -> bytes:
    """Crop `crop` (black where it leaves the frame), resize it and draw `box`."""
    # Whole pixels, grown outwards, so the box maps exactly onto the crop taken.
    x1, y1 = math.floor(crop[0]), math.floor(crop[1])
    x2, y2 = math.ceil(crop[2]), math.ceil(crop[3])
    if x2 <= x1 or y2 <= y1:
        raise ValueError(f"Empty crop: {crop}")
    with Image.open(BytesIO(jpeg)) as source:
        # Pillow fills the area outside the image with zeros: black for RGB.
        cropped = source.convert("RGB").crop((x1, y1, x2, y2))
    image = cropped.resize(out_size, Image.Resampling.LANCZOS)
    sx = out_size[0] / (x2 - x1)
    sy = out_size[1] / (y2 - y1)
    _draw_box(
        image, ((box[0] - x1) * sx, (box[1] - y1) * sy, (box[2] - x1) * sx, (box[3] - y1) * sy)
    )
    return _encode(image, quality)


def render_full(jpeg: bytes, box: Box | None, quality: int = FULL_QUALITY) -> bytes:
    """Draw `box` on the whole frame; with no box the frame is returned as is."""
    if box is None:
        return jpeg
    with Image.open(BytesIO(jpeg)) as source:
        image = source.convert("RGB")
    _draw_box(image, box)
    return _encode(image, quality)
