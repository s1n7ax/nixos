"""Drawing the photo, the dimmed surround and the four handles."""

from __future__ import annotations

import math
from dataclasses import dataclass

import cairo
import numpy as np
from PIL import Image

from viewport import Viewport

PREVIEW_MAX = 2400
HANDLE_RADIUS = 11.0
HANDLE_GROWTH = 3.0
OUTLINE_WIDTH = 2.0
ACCENT = (0.36, 0.78, 1.0)
BACKGROUND = (0.06, 0.06, 0.08)
DIM_ALPHA = 0.55


@dataclass(frozen=True)
class Preview:
    """A screen-sized copy of the photo, ready for cairo to blit."""

    surface: cairo.ImageSurface
    buffer: bytearray
    scale: float


def preview_surface(image: Image.Image) -> Preview:
    """Shrink the photo to screen size and hand cairo the pixels it expects.

    Cairo reads RGB24 rows as BGRX, so the channels are shuffled once here
    instead of on every frame. The buffer is kept alive by the returned Preview
    because the surface only borrows it.
    """
    preview = image.convert("RGB")
    preview.thumbnail((PREVIEW_MAX, PREVIEW_MAX), Image.Resampling.LANCZOS)

    rgb = np.asarray(preview, dtype=np.uint8)
    bgrx = np.empty((preview.height, preview.width, 4), dtype=np.uint8)
    bgrx[:, :, 0] = rgb[:, :, 2]
    bgrx[:, :, 1] = rgb[:, :, 1]
    bgrx[:, :, 2] = rgb[:, :, 0]
    bgrx[:, :, 3] = 255

    buffer = bytearray(bgrx.tobytes())
    surface = cairo.ImageSurface.create_for_data(
        memoryview(buffer),
        cairo.FORMAT_RGB24,
        preview.width,
        preview.height,
        preview.width * 4,
    )
    return Preview(surface=surface, buffer=buffer, scale=preview.width / image.width)


def _trace_quad(context: cairo.Context, points: list[tuple[float, float]]) -> None:
    context.move_to(*points[0])
    for point in points[1:]:
        context.line_to(*point)
    context.close_path()


def draw_scene(
    context: cairo.Context,
    canvas_size: tuple[float, float],
    preview: Preview,
    viewport: Viewport,
    corners,
    selected: int,
) -> None:
    """Paint one frame: photo, everything outside the selection dimmed, handles on top."""
    width, height = canvas_size

    context.set_source_rgb(*BACKGROUND)
    context.paint()

    context.save()
    context.translate(viewport.offset_x, viewport.offset_y)
    factor = viewport.scale / preview.scale
    context.scale(factor, factor)
    context.set_source_surface(preview.surface, 0, 0)
    context.get_source().set_filter(cairo.Filter.BILINEAR)
    context.paint()
    context.restore()

    points = [viewport.to_display(corner) for corner in corners]

    context.set_fill_rule(cairo.FillRule.EVEN_ODD)
    context.rectangle(0, 0, width, height)
    _trace_quad(context, points)
    context.set_source_rgba(0.0, 0.0, 0.0, DIM_ALPHA)
    context.fill()
    context.set_fill_rule(cairo.FillRule.WINDING)

    _trace_quad(context, points)
    context.set_source_rgba(*ACCENT, 0.95)
    context.set_line_width(OUTLINE_WIDTH)
    context.stroke()

    for index, (x, y) in enumerate(points):
        active = index == selected
        context.arc(x, y, HANDLE_RADIUS + (HANDLE_GROWTH if active else 0.0), 0, 2 * math.pi)
        if active:
            context.set_source_rgba(*ACCENT, 0.95)
        else:
            context.set_source_rgba(1.0, 1.0, 1.0, 0.9)
        context.fill_preserve()
        context.set_source_rgb(*BACKGROUND)
        context.set_line_width(OUTLINE_WIDTH)
        context.stroke()
