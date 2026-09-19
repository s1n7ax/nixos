"""The preflight level bar."""

from __future__ import annotations

import unittest

import meter


class TestPeak(unittest.TestCase):
    def test_reads_a_peak_line(self):
        line = "lavfi.astats.Overall.Peak_level=-42.113"
        self.assertAlmostEqual(meter.parse_peak(line), -42.113)

    def test_silence_reads_as_the_floor(self):
        self.assertEqual(meter.parse_peak("lavfi.astats.Overall.Peak_level=-inf"), meter.FLOOR)

    def test_any_other_line_is_not_a_reading(self):
        self.assertIsNone(meter.parse_peak("frame=  120 fps=25"))


class TestBar(unittest.TestCase):
    def test_a_quiet_room_barely_moves(self):
        self.assertLess(meter.bar(-42).count("#"), meter.WIDTH // 3)

    def test_speech_fills_most_of_it(self):
        self.assertGreater(meter.bar(-6).count("#"), meter.WIDTH * 2 // 3)

    def test_it_never_overflows_or_goes_negative(self):
        for level in [-200.0, meter.FLOOR, -60.0, 0.0, 12.0]:
            self.assertEqual(len(meter.bar(level)), meter.WIDTH)

    def test_the_line_names_the_level(self):
        self.assertIn("-42.1", meter.line(-42.113, "some.monitor"))

    def test_the_line_shows_the_resolved_desktop_source(self):
        """The eye confirms the source in the same glance that confirms the mic is live."""
        self.assertIn("some.monitor", meter.line(-42.113, "some.monitor"))


if __name__ == "__main__":
    unittest.main()
