"""Reading the live-view burst that preflight gates on."""

from __future__ import annotations

import unittest

import camera
import config


def jpeg(width: int, height: int, padding: int = 4) -> bytes:
    """A frame with just enough of a baseline header to carry its geometry."""
    sof = b"\xff\xc0\x00\x11\x08" + height.to_bytes(2, "big") + width.to_bytes(2, "big") + b"\x03" * 7
    return b"\xff\xd8" + sof + b"\x5a" * padding + b"\xff\xd9"


class TestGeometry(unittest.TestCase):
    def test_reads_a_baseline_frame(self):
        self.assertEqual(camera.jpeg_size(jpeg(1024, 576)), (1024, 576))

    def test_reads_the_stills_geometry_too(self):
        self.assertEqual(camera.jpeg_size(jpeg(960, 640)), (960, 640))

    def test_a_frame_with_no_header_has_no_geometry(self):
        self.assertIsNone(camera.jpeg_size(b"\xff\xd8\xff\xd9"))

    def test_does_not_mistake_payload_bytes_for_a_marker(self):
        """A quantisation table may hold the bytes FF C0; only segment walking skips them."""
        quantisation = b"\xff\xdb\x00\x06\x00\xff\xc0\x11"
        sof = b"\xff\xc0\x00\x11\x08" + (576).to_bytes(2, "big") + (1024).to_bytes(2, "big") + b"\x03" * 7
        frame = b"\xff\xd8" + quantisation + sof + b"\xff\xd9"
        self.assertEqual(frame.find(b"\xff\xc0"), 7, "fixture must bait a naive search")
        self.assertEqual(camera.jpeg_size(frame), (1024, 576))


class TestSplitting(unittest.TestCase):
    def test_splits_concatenated_frames_and_keeps_the_tail(self):
        stream = jpeg(1024, 576) + jpeg(1024, 576) + b"\xff\xd8\xff\xc0"
        frames, remainder = camera.split_frames(stream)
        self.assertEqual(len(frames), 2)
        self.assertEqual(remainder, b"\xff\xd8\xff\xc0")

    def test_leading_junk_before_the_first_frame_is_dropped(self):
        frames, remainder = camera.split_frames(b"noise" + jpeg(1024, 576))
        self.assertEqual(len(frames), 1)
        self.assertEqual(remainder, b"")

    def test_nothing_complete_yet(self):
        frames, remainder = camera.split_frames(b"\xff\xd8\xff")
        self.assertEqual(frames, [])
        self.assertEqual(remainder, b"\xff\xd8\xff")


class TestProbe(unittest.TestCase):
    def test_measures_geometry_and_rate_from_the_settled_tail(self):
        """The camera emits one or two stale-geometry frames after any mode change."""
        sizes = [(960, 640), (960, 640)] + [(1024, 576)] * 48
        arrivals = [index * 0.04 for index in range(len(sizes))]
        probe = camera.Probe.of(sizes, arrivals)
        self.assertEqual(probe.geometry, (1024, 576))
        self.assertAlmostEqual(probe.fps, 25.0, places=1)
        self.assertEqual(probe.frames, 50)

    def test_a_short_burst_still_measures(self):
        probe = camera.Probe.of([(1024, 576)] * 3, [0.0, 0.04, 0.08])
        self.assertEqual(probe.geometry, (1024, 576))
        self.assertAlmostEqual(probe.fps, 25.0, places=1)

    def test_no_frames_at_all(self):
        probe = camera.Probe.of([], [])
        self.assertIsNone(probe.geometry)
        self.assertEqual(probe.fps, 0.0)


class TestGate(unittest.TestCase):
    def test_the_settled_movie_feed_passes(self):
        self.assertEqual(camera.gate(camera.Probe.of([(1024, 576)] * 50, [i * 0.04 for i in range(50)])), [])

    def test_stills_mode_is_refused_by_geometry(self):
        problems = camera.gate(camera.Probe.of([(960, 640)] * 50, [i / 30 for i in range(50)]))
        self.assertTrue(any("960x640" in problem for problem in problems))

    def test_the_movie_rate_menu_left_on_fifty_is_refused(self):
        problems = camera.gate(camera.Probe.of([(1024, 576)] * 50, [i * 0.02 for i in range(50)]))
        self.assertTrue(any("50.0" in problem for problem in problems))

    def test_a_small_liveviewsize_is_refused(self):
        problems = camera.gate(camera.Probe.of([(512, 288)] * 50, [i * 0.04 for i in range(50)]))
        self.assertTrue(any("liveviewsize" in problem for problem in problems))

    def test_a_dead_camera_is_refused(self):
        self.assertTrue(camera.gate(camera.Probe.of([], [])))

    def test_the_band_comes_from_config(self):
        self.assertEqual((config.CAMERA_RATE_MIN, config.CAMERA_RATE_MAX), (24.5, 25.5))


if __name__ == "__main__":
    unittest.main()
