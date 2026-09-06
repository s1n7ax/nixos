"""Unit tests for the file helpers: python3 test_imagefile.py"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image

import imagefile

ORIENTATION_TAG = 274
ROTATE_90_CLOCKWISE = 6


class LoadTest(unittest.TestCase):
    def test_exif_orientation_is_applied_to_the_pixels(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "photo.jpg"
            exif = Image.Exif()
            exif[ORIENTATION_TAG] = ROTATE_90_CLOCKWISE
            Image.new("RGB", (200, 100), "white").save(path, exif=exif)

            self.assertEqual(imagefile.load(path).size, (100, 200))


class SaveInPlaceTest(unittest.TestCase):
    def test_the_original_path_holds_the_new_picture(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "photo.jpg"
            Image.new("RGB", (200, 100), "white").save(path)

            imagefile.save_in_place(Image.new("RGB", (40, 30), "black"), path)

            with Image.open(path) as saved:
                self.assertEqual(saved.size, (40, 30))
                self.assertEqual(saved.format, "JPEG")

    def test_transparency_is_flattened_only_for_jpeg(self):
        with tempfile.TemporaryDirectory() as directory:
            jpeg = Path(directory) / "photo.jpg"
            png = Path(directory) / "photo.png"
            transparent = Image.new("RGBA", (20, 20), (255, 0, 0, 0))

            imagefile.save_in_place(transparent, jpeg)
            imagefile.save_in_place(transparent, png)

            with Image.open(jpeg) as saved:
                self.assertEqual(saved.mode, "RGB")
            with Image.open(png) as saved:
                self.assertEqual(saved.mode, "RGBA")

    def test_a_photo_without_an_extension_keeps_its_original_format(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scan"
            Image.new("RGB", (30, 30), "white").save(path, format="PNG")
            loaded = imagefile.load(path)

            imagefile.save_in_place(loaded, path, loaded.format)

            with Image.open(path) as saved:
                self.assertEqual(saved.format, "PNG")

    def test_a_symlinked_photo_is_followed_to_the_real_file(self):
        with tempfile.TemporaryDirectory() as directory:
            real = Path(directory) / "photo.png"
            link = Path(directory) / "link.png"
            Image.new("RGB", (60, 60), "white").save(real)
            link.symlink_to(real)

            imagefile.save_in_place(Image.new("RGB", (12, 12), "white"), link)

            self.assertTrue(link.is_symlink())
            with Image.open(real) as saved:
                self.assertEqual(saved.size, (12, 12))

    def test_the_original_permissions_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "photo.png"
            Image.new("RGB", (20, 20), "white").save(path)
            path.chmod(0o600)

            imagefile.save_in_place(Image.new("RGB", (10, 10), "white"), path)

            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_no_temporary_file_is_left_behind(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "photo.png"
            Image.new("RGB", (20, 20), "white").save(path)

            imagefile.save_in_place(Image.new("RGB", (10, 10), "white"), path)

            self.assertEqual([p.name for p in Path(directory).iterdir()], ["photo.png"])


if __name__ == "__main__":
    unittest.main()
