"""Unit tests for the frame drawing: python3 test_render.py"""

from __future__ import annotations

import unittest

import cairo
import numpy as np
from PIL import Image

from render import draw_scene, preview_surface
from viewport import Viewport

CANVAS = (400, 300)


def render(corners, selected=0, image=None):
    """Draw one frame of a plain white photo and read the canvas back as RGB."""
    photo = image or Image.new("RGB", (200, 100), "white")
    surface = cairo.ImageSurface(cairo.FORMAT_RGB24, *CANVAS)
    viewport = Viewport.fit(photo.size, CANVAS, margin=0)

    draw_scene(cairo.Context(surface), CANVAS, preview_surface(photo), viewport, corners, selected)
    surface.flush()

    pixels = np.ndarray(
        shape=(CANVAS[1], surface.get_stride() // 4, 4),
        dtype=np.uint8,
        buffer=surface.get_data(),
    )
    return pixels[:, : CANVAS[0], 2::-1]


class DrawSceneTest(unittest.TestCase):
    def test_the_photo_is_scaled_to_fill_the_canvas_width(self):
        frame = render(((0, 0), (200, 0), (200, 100), (0, 100)))

        self.assertGreater(frame[150, 200].min(), 240)
        self.assertLess(frame[5, 200].max(), 40)

    def test_everything_outside_the_selection_is_dimmed(self):
        frame = render(((100, 0), (200, 0), (200, 100), (100, 100)))

        inside = frame[150, 300].mean()
        outside = frame[150, 100].mean()
        self.assertGreater(inside, 240)
        self.assertLess(outside, 150)
        self.assertGreater(outside, 60)

    def test_the_channels_are_not_swapped(self):
        photo = Image.new("RGB", (200, 100), (200, 40, 20))

        frame = render(((0, 0), (200, 0), (200, 100), (0, 100)), image=photo)

        red, green, blue = frame[150, 200]
        self.assertGreater(int(red), 180)
        self.assertLess(int(green), 70)
        self.assertLess(int(blue), 60)

    def test_a_handle_is_painted_on_every_corner(self):
        corners = ((0, 0), (200, 0), (200, 100), (0, 100))

        frame = render(corners, selected=1)

        viewport = Viewport.fit((200, 100), CANVAS, margin=0)
        for corner in corners:
            x, y = viewport.to_display(corner)
            patch = frame[max(0, int(y) - 3) : int(y) + 3, max(0, int(x) - 3) : int(x) + 3]
            self.assertGreater(patch.mean(), 100)

    def test_the_selected_handle_is_the_accent_colour(self):
        corners = ((20, 20), (180, 20), (180, 80), (20, 80))

        frame = render(corners, selected=2)

        viewport = Viewport.fit((200, 100), CANVAS, margin=0)
        x, y = viewport.to_display(corners[2])
        red, green, blue = frame[int(y), int(x)]
        self.assertGreater(int(blue), int(red) + 60)


if __name__ == "__main__":
    unittest.main()
