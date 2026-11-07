"""Pillow rendering of notification thumbnails and review images.

Each box is drawn with its label (the type name, such as "Person") in a filled
tab on its top-left corner. Takes JPEG bytes or a decoded frame and rectangles
already worked out by `core.geometry`, so it has no imports from the
integration and runs in an executor thread.
"""

from __future__ import annotations

import math
from io import BytesIO

from PIL import Image, ImageDraw, ImageFont

Box = tuple[float, float, float, float]
Size = tuple[int, int]

THUMB_SIZE: Size = (1024, 512)
THUMB_QUALITY = 90
FULL_QUALITY = 92
BOX_COLOR = (255, 40, 40)
LABEL_COLOR = (255, 255, 255)
# Label text size, as a share of the image height.
FULL_LABEL_SHARE = 1 / 30
FULL_LABEL_MIN = 14
THUMB_LABEL_SHARE = 1 / 20
# What Pillow raises for bytes it cannot read as an image.
_READ_ERRORS = (OSError, ValueError, Image.DecompressionBombError)


class ImageRenderError(ValueError):
    """A frame could not be decoded, or the requested crop is empty."""


def _open(jpeg: bytes) -> Image.Image:
    """Decode a frame.

    Raises:
        ImageRenderError: the bytes are not an image Pillow can read.
    """
    try:
        with Image.open(BytesIO(jpeg)) as source:
            return source.convert("RGB")
    except _READ_ERRORS as err:
        raise ImageRenderError(f"Cannot read the frame: {err}") from err


def image_size(jpeg: bytes) -> Size:
    """Return a frame's (width, height), read from its header without decoding it.

    Raises:
        ImageRenderError: the bytes are not an image Pillow can read.
    """
    try:
        with Image.open(BytesIO(jpeg)) as source:
            return source.size
    except _READ_ERRORS as err:
        raise ImageRenderError(f"Cannot read the frame: {err}") from err


def _line_width(size: Size) -> int:
    return max(2, round(min(size) / 170))


def _draw_box(image: Image.Image, box: Box) -> None:
    ImageDraw.Draw(image).rectangle(
        [round(v) for v in box], outline=BOX_COLOR, width=_line_width(image.size)
    )


def _draw_label(image: Image.Image, box: Box, label: str, text_size: int) -> None:
    """Draw `label` in a tab joined to the box's top-left corner.

    The tab sits above the box when it fits inside the image, otherwise inside
    the box along its top edge, and moves left rather than leave the image.
    """
    # Pillow's built-in scalable font, so no font file is needed.
    font = ImageFont.load_default(size=text_size)
    pad = max(2, round(text_size / 4))
    width = math.ceil(font.getlength(label)) + 2 * pad
    height = text_size + pad
    x1, y1 = round(box[0]), round(box[1])
    left = max(0, min(x1, image.width - width))
    top = y1 - height if y1 >= height else y1
    draw = ImageDraw.Draw(image)
    draw.rectangle([left, top, left + width - 1, top + height - 1], fill=BOX_COLOR)
    draw.text((left + pad, top + height / 2), label, fill=LABEL_COLOR, font=font, anchor="lm")


def _encode(image: Image.Image, quality: int) -> bytes:
    out = BytesIO()
    image.save(out, format="JPEG", quality=quality, optimize=True)
    return out.getvalue()


def render_crop(
    jpeg: bytes,
    crop: Box,
    box: Box,
    label: str,
    out_size: Size = THUMB_SIZE,
    quality: int = THUMB_QUALITY,
) -> bytes:
    """Crop `crop` (black where it leaves the frame), resize it and draw `box` and `label`.

    Raises:
        ImageRenderError: the frame cannot be read, or the crop is empty.
    """
    # Whole pixels, grown outwards, so the box maps exactly onto the crop taken.
    x1, y1 = math.floor(crop[0]), math.floor(crop[1])
    x2, y2 = math.ceil(crop[2]), math.ceil(crop[3])
    if x2 <= x1 or y2 <= y1:
        raise ImageRenderError(f"Empty crop: {crop}")
    # Pillow fills the area outside the image with zeros: black for RGB.
    cropped = _open(jpeg).crop((x1, y1, x2, y2))
    image = cropped.resize(out_size, Image.Resampling.LANCZOS)
    sx = out_size[0] / (x2 - x1)
    sy = out_size[1] / (y2 - y1)
    mapped = ((box[0] - x1) * sx, (box[1] - y1) * sy, (box[2] - x1) * sx, (box[3] - y1) * sy)
    _draw_box(image, mapped)
    _draw_label(image, mapped, label, round(out_size[1] * THUMB_LABEL_SHARE))
    return _encode(image, quality)


def render_frame(image: Image.Image, box: Box, label: str, quality: int = FULL_QUALITY) -> bytes:
    """Draw `box` and `label` on a decoded RGB frame, in place, and encode it."""
    _draw_box(image, box)
    _draw_label(image, box, label, max(FULL_LABEL_MIN, round(image.height * FULL_LABEL_SHARE)))
    return _encode(image, quality)


def render_full(jpeg: bytes, box: Box | None, label: str, quality: int = FULL_QUALITY) -> bytes:
    """Draw `box` and `label` on the whole frame; with no box the frame is returned as is.

    Raises:
        ImageRenderError: the frame cannot be read.
    """
    if box is None:
        return jpeg
    return render_frame(_open(jpeg), box, label, quality)
