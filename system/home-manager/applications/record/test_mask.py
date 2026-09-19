"""The mask the build bakes, and the numbers it shares with the Nix expression."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

import config
import mask


class TestDescription(unittest.TestCase):
    def test_named_after_its_diameter(self):
        self.assertEqual(mask.filename(), "circle-mask-540.png")

    def test_the_source_is_the_prototyped_expression(self):
        self.assertEqual(
            mask.lavfi_source(),
            "color=c=black:s=540x540,format=gray,"
            "geq=lum='clip((270-hypot(X-269.5,Y-269.5))*255/3,0,255)'",
        )

    def test_the_numbers_come_from_config_alone(self):
        self.assertIn(str(config.CIRCLE_DIAMETER), mask.filename())
        self.assertIn(f"/{config.MASK_FEATHER},", mask.lavfi_source())


class TestRendered(unittest.TestCase):
    """The mask is what the GPU alpha path was proved against, so it must not drift."""

    def test_renders_a_feathered_disc_of_the_right_size(self):
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / mask.filename()
            rendered = subprocess.run(
                ["ffmpeg", "-v", "error", "-f", "lavfi", "-i", mask.lavfi_source(),
                 "-frames:v", "1", str(path)],
                capture_output=True,
                check=False,
            )
            if rendered.returncode != 0:
                self.skipTest("ffmpeg unavailable")
            probed = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "stream=width,height,pix_fmt",
                 "-of", "csv=p=0", str(path)],
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip()
            self.assertEqual(probed, f"{config.CIRCLE_DIAMETER},{config.CIRCLE_DIAMETER},gray")


if __name__ == "__main__":
    unittest.main()
