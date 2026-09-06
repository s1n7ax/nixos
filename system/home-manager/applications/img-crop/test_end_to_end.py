"""The whole crop path a keypress triggers, minus the widgets: python3 test_end_to_end.py"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import imagefile
from perspective import warp
from selection import Selection
from viewport import Viewport

PAGE = ((180.0, 120.0), (760.0, 60.0), (830.0, 690.0), (250.0, 740.0))


def photograph(path: Path) -> None:
    """A dark snapshot with a white sheet of paper lying askew in it."""
    photo = Image.new("RGB", (900, 800), (30, 30, 34))
    drawing = ImageDraw.Draw(photo)
    drawing.polygon(PAGE, fill="white")
    drawing.line((300, 260, 700, 230), fill="black", width=8)
    photo.save(path)


class CropInPlaceTest(unittest.TestCase):
    def test_dragging_the_corners_onto_the_page_yields_a_straight_scan(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "photo.jpg"
            photograph(path)

            image = imagefile.load(path)
            selection = Selection(image.width, image.height)
            viewport = Viewport.fit(image.size, (1280.0, 800.0), margin=28.0)
            for index, corner in enumerate(PAGE):
                selection.move(index, viewport.to_image(viewport.to_display(corner)))

            imagefile.save_in_place(warp(image, selection.corners), path)

            cropped = imagefile.load(path)
            self.assertLess(cropped.width, image.width)
            page = np.asarray(cropped.convert("L"), dtype=float)
            self.assertGreater(page[:, 2].mean(), 200)
            self.assertGreater(page[:, -3].mean(), 200)
            self.assertGreater(page[2, :].mean(), 200)
            self.assertGreater(page[-3, :].mean(), 200)

    def test_leaving_the_default_selection_alone_keeps_the_photo_usable(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "photo.jpg"
            photograph(path)
            original = imagefile.load(path)

            selection = Selection(original.width, original.height)
            imagefile.save_in_place(warp(original, selection.corners), path)

            cropped = imagefile.load(path)
            self.assertEqual(cropped.size, (810, 720))


if __name__ == "__main__":
    unittest.main()
