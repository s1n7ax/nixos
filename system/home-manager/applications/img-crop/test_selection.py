"""Unit tests for the corner state: python3 test_selection.py"""

from __future__ import annotations

import unittest

from selection import Selection
from viewport import Viewport


class ViewportTest(unittest.TestCase):
    def test_a_wide_photo_is_letterboxed_inside_a_square_canvas(self):
        viewport = Viewport.fit((200, 100), (400, 400))

        self.assertAlmostEqual(viewport.scale, 2.0)
        self.assertAlmostEqual(viewport.offset_x, 0.0)
        self.assertAlmostEqual(viewport.offset_y, 100.0)

    def test_the_margin_is_kept_free_on_every_side(self):
        viewport = Viewport.fit((100, 100), (300, 300), margin=50)

        self.assertAlmostEqual(viewport.scale, 2.0)
        self.assertAlmostEqual(viewport.offset_x, 50.0)

    def test_display_and_image_coordinates_round_trip(self):
        viewport = Viewport.fit((640, 480), (1000, 700), margin=24)

        x, y = viewport.to_image(viewport.to_display((123.0, 45.0)))
        self.assertAlmostEqual(x, 123.0)
        self.assertAlmostEqual(y, 45.0)


class SelectionTest(unittest.TestCase):
    def test_it_starts_just_inside_the_photo(self):
        selection = Selection(1000, 800, inset=0.1)

        self.assertEqual(
            selection.corners,
            ((100.0, 80.0), (900.0, 80.0), (900.0, 720.0), (100.0, 720.0)),
        )

    def test_a_corner_cannot_be_dragged_off_the_photo(self):
        selection = Selection(100, 100)

        selection.move(0, (-40.0, 500.0))

        self.assertEqual(selection.corners[0], (0.0, 100.0))

    def test_nudging_shifts_the_corner_by_whole_pixels(self):
        selection = Selection(100, 100, inset=0.0)

        selection.nudge(2, (-5.0, -3.0))

        self.assertEqual(selection.corners[2], (95.0, 97.0))

    def test_the_closest_corner_is_grabbed(self):
        selection = Selection(100, 100, inset=0.0)

        self.assertEqual(selection.nearest((90.0, 90.0)), 2)

    def test_nothing_is_grabbed_when_the_click_is_far_away(self):
        selection = Selection(100, 100, inset=0.0)

        self.assertIsNone(selection.nearest((50.0, 50.0), within=10.0))

    def test_reset_undoes_every_drag(self):
        selection = Selection(100, 100, inset=0.0)
        selection.move(1, (10.0, 10.0))

        selection.reset()

        self.assertEqual(selection.corners[1], (100.0, 0.0))

    def test_selection_cycles_through_the_four_corners(self):
        selection = Selection(100, 100)

        selection.select_next(-1)

        self.assertEqual(selection.selected, 3)


if __name__ == "__main__":
    unittest.main()
