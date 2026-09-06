"""Unit tests for the perspective helpers: python3 test_perspective.py"""

from __future__ import annotations

import unittest

import numpy as np
from PIL import Image, ImageDraw

from perspective import (
    full_frame,
    output_size,
    perspective_coefficients,
    project,
    warp,
)


class OutputSizeTest(unittest.TestCase):
    def test_axis_aligned_rectangle_keeps_its_size(self):
        corners = ((10, 20), (110, 20), (110, 70), (10, 70))
        self.assertEqual(output_size(corners), (100, 50))

    def test_longer_of_each_opposite_pair_wins(self):
        corners = ((0, 0), (80, 0), (100, 60), (0, 60))
        self.assertEqual(output_size(corners), (100, 63))

    def test_degenerate_quad_still_has_a_pixel(self):
        corners = ((5, 5), (5, 5), (5, 5), (5, 5))
        self.assertEqual(output_size(corners), (1, 1))


class CoefficientsTest(unittest.TestCase):
    def test_each_destination_corner_maps_onto_its_source_corner(self):
        source = ((12.0, 30.0), (190.0, 5.0), (210.0, 260.0), (30.0, 240.0))
        destination = ((0.0, 0.0), (180.0, 0.0), (180.0, 250.0), (0.0, 250.0))

        coefficients = perspective_coefficients(destination, source)

        for out_point, in_point in zip(destination, source, strict=True):
            mapped = project(coefficients, out_point)
            self.assertAlmostEqual(mapped[0], in_point[0], places=6)
            self.assertAlmostEqual(mapped[1], in_point[1], places=6)


class WarpTest(unittest.TestCase):
    def test_selecting_the_whole_frame_returns_the_same_picture(self):
        image = Image.effect_noise((64, 48), 40).convert("RGB")

        result = warp(image, full_frame(*image.size))

        self.assertEqual(result.size, image.size)
        difference = np.abs(
            np.asarray(result, dtype=float) - np.asarray(image, dtype=float)
        )
        self.assertLess(difference.mean(), 1.0)

    def test_a_skewed_page_is_straightened_into_a_full_rectangle(self):
        image = Image.new("RGB", (400, 300), "black")
        page = ((60, 40), (330, 20), (360, 250), (90, 275))
        ImageDraw.Draw(image).polygon(page, fill="white")

        result = warp(image, page)

        self.assertEqual(result.size, output_size(page))
        pixels = np.asarray(result.convert("L"), dtype=float)
        self.assertGreater(pixels.mean(), 250)
        for corner in ((2, 2), (-3, 2), (2, -3), (-3, -3)):
            self.assertGreater(pixels[corner[1], corner[0]], 200)

    def test_the_colour_profile_survives_the_crop(self):
        image = Image.new("RGB", (60, 60), "white")
        image.info["icc_profile"] = b"pretend-profile"

        result = warp(image, full_frame(*image.size))

        self.assertEqual(result.info["icc_profile"], b"pretend-profile")

    def test_the_area_outside_the_selection_is_dropped(self):
        image = Image.new("RGB", (200, 200), "red")
        ImageDraw.Draw(image).rectangle((50, 50, 149, 149), fill="lime")

        result = warp(image, ((50, 50), (150, 50), (150, 150), (50, 150)))

        pixels = np.asarray(result)
        self.assertEqual(result.size, (100, 100))
        self.assertGreater((pixels[:, :, 1] > 200).mean(), 0.98)


if __name__ == "__main__":
    unittest.main()
