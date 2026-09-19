"""The command lines. Every assertion here is a measured decision from a ticket."""

from __future__ import annotations

import unittest

import config
import pipeline


def flag_value(argv: list[str], flag: str) -> str | None:
    return argv[argv.index(flag) + 1] if flag in argv else None


class TestScreenCapture(unittest.TestCase):
    def setUp(self):
        self.argv = pipeline.wf_recorder_argv()

    def test_grabs_the_one_monitor_as_raw_frames(self):
        self.assertEqual(flag_value(self.argv, "-o"), config.MONITOR)
        self.assertEqual(flag_value(self.argv, "-c"), "rawvideo")
        self.assertEqual(flag_value(self.argv, "-m"), "rawvideo")

    def test_hands_over_yuv420p_so_the_main_input_needs_no_conversion(self):
        self.assertEqual(flag_value(self.argv, "-x"), "yuv420p")

    def test_pins_the_rate_because_raw_frames_over_a_pipe_carry_no_timestamps(self):
        self.assertEqual(flag_value(self.argv, "-r"), str(config.OUTPUT_FPS))

    def test_writes_to_stdout(self):
        self.assertIn("--file=pipe:1", self.argv)


class TestCameraCapture(unittest.TestCase):
    def test_opens_live_view_on_stdout(self):
        argv = pipeline.gphoto2_argv()
        self.assertEqual(argv[0], "gphoto2")
        self.assertIn("--stdout", argv)
        self.assertIn("--capture-movie", argv)
        self.assertIn("viewfinder=1", argv)

    def test_the_warm_up_burst_stops_itself(self):
        argv = pipeline.gphoto2_argv(frames=60)
        self.assertIn("--capture-movie=60", argv)
        self.assertNotIn("--capture-movie", argv)


class TestFilterGraph(unittest.TestCase):
    def setUp(self):
        self.graph = pipeline.filter_graph()

    def test_the_circle_is_the_prototyped_chain(self):
        self.assertIn(
            "crop=576:576:224:0,scale=528:528,pad=540:540:6:6:0x89b4fa,format=rgba",
            self.graph,
        )

    def test_the_mask_is_a_static_png_through_alphamerge_never_geq(self):
        self.assertIn("alphamerge", self.graph)
        self.assertNotIn("geq", self.graph)

    def test_the_overlay_carries_alpha_onto_the_gpu(self):
        self.assertIn("format=yuva420p,hwupload_cuda", self.graph)

    def test_the_main_input_is_yuv420p_before_the_upload(self):
        self.assertIn("format=yuv420p,hwupload_cuda", self.graph)

    def test_the_circle_sits_bottom_right(self):
        self.assertIn("overlay_cuda=x=2860:y=860", self.graph)

    def test_a_dead_camera_removes_the_circle_rather_than_freezing_it(self):
        self.assertIn("eof_action=pass", self.graph)

    def test_the_preview_is_a_split_not_a_second_capture(self):
        self.assertIn("split=2", self.graph)
        self.assertIn(f"scale={config.HUD_WIDTH}", self.graph)

    def test_the_mix_is_not_normalised_and_leans_on_the_mic(self):
        self.assertIn(f"amix=inputs=2:normalize=0:weights={config.MIX_WEIGHTS}", self.graph)

    def test_the_mic_track_is_downmixed_to_mono(self):
        self.assertIn("pan=mono|c0=0.5*c0+0.5*c1", self.graph)

    def test_the_raw_tracks_are_untouched(self):
        """Tracks 1 and 2 are pristine, so a bad mix is always recoverable."""
        self.assertNotIn("alimiter", self.graph)
        self.assertNotIn("loudnorm", self.graph)


class TestFfmpeg(unittest.TestCase):
    def setUp(self):
        self.argv = pipeline.ffmpeg_argv(
            screen_fd=7,
            camera_fd=8,
            mask="/mask.png",
            mic="mic-source",
            desktop="desk-source",
            output="/takes/x UNTITLED.mkv",
            preview="/run/preview.fifo",
        )

    def test_reads_both_pipes_by_file_descriptor(self):
        self.assertIn("pipe:7", self.argv)
        self.assertIn("pipe:8", self.argv)

    def test_both_pipes_are_anchored_to_the_wall_clock(self):
        """A declared 25 against the real 25.04 drifts the circle 3.8 s over 40 minutes."""
        self.assertEqual(self.argv.count("-use_wallclock_as_timestamps"), 2)

    def test_no_input_declares_a_frame_rate(self):
        """The wall clock anchors all four inputs; a declared 25 is a lie on this camera."""
        self.assertNotIn("-framerate", self.argv)

    def test_the_camera_input_is_given_no_geometry(self):
        """-video_size is a hard error on the mjpeg demuxer; the warm-up is the guard."""
        self.assertNotIn("-video_size", self.argv[self.argv.index("-f", self.argv.index("mjpeg") - 1) :])

    def test_the_raw_pipe_gets_a_deep_queue(self):
        self.assertIn("-thread_queue_size", self.argv)
        self.assertEqual(flag_value(self.argv, "-thread_queue_size"), str(config.THREAD_QUEUE_SIZE))

    def test_the_encoder_is_h264_not_hevc(self):
        """Pascal's HEVC is ~30% less efficient here and hard-fails on -bf 3."""
        self.assertIn("h264_nvenc", self.argv)
        self.assertNotIn("hevc_nvenc", self.argv)

    def test_the_measured_encode_settings(self):
        for flag, value in [
            ("-preset", "p4"),
            ("-tune", "hq"),
            ("-rc", "vbr"),
            ("-cq", "23"),
            ("-b:v", "0"),
            ("-g", "100"),
            ("-bf", "3"),
            ("-spatial-aq", "1"),
            ("-aq-strength", "8"),
            ("-rc-lookahead", "20"),
        ]:
            self.assertEqual(flag_value(self.argv, flag), value, flag)

    def test_no_pix_fmt_on_the_nvenc_output(self):
        """The encoder takes CUDA frames straight from overlay_cuda."""
        self.assertNotIn("-pix_fmt", self.argv)

    def test_the_output_is_locked_to_fifty_constant(self):
        self.assertEqual(flag_value(self.argv, "-fps_mode"), "cfr")
        self.assertEqual(flag_value(self.argv, "-r"), str(config.OUTPUT_FPS))

    def test_three_audio_tracks_mix_first(self):
        self.assertEqual(flag_value(self.argv, "-c:a:0"), "aac")
        self.assertEqual(flag_value(self.argv, "-b:a:0"), "192k")
        self.assertEqual(flag_value(self.argv, "-b:a:1"), "96k")
        self.assertEqual(flag_value(self.argv, "-b:a:2"), "192k")

    def test_tracks_are_labelled_twice_so_the_names_survive_an_mp4_export(self):
        for index, label in enumerate(["Mix", "Mic", "Desktop"]):
            self.assertIn(f"title={label}", self.argv)
            self.assertIn(f"handler_name={label}", self.argv)
            self.assertIn(f"-metadata:s:a:{index}", self.argv)

    def test_the_streams_are_named_so_the_watcher_can_tell_them_apart(self):
        self.assertIn("record-mic", self.argv)
        self.assertIn("record-desktop", self.argv)

    def test_the_preview_output_drops_packets_and_never_attempts_recovery(self):
        """A slow reader otherwise back-pressures the encoder and collapses the take."""
        self.assertIn("-drop_pkts_on_overflow", self.argv)
        self.assertNotIn("-attempt_recovery", self.argv)
        self.assertNotIn("-recover_any_error", self.argv)
        self.assertEqual(flag_value(self.argv, "-fifo_format"), "nut")

    def test_the_take_is_written_before_the_preview(self):
        self.assertLess(self.argv.index("/takes/x UNTITLED.mkv"), self.argv.index("/run/preview.fifo"))

    def test_nothing_carries_its_own_stop_condition(self):
        """Every output needs to end on Ctrl-C; -t on one of them ran on for minutes."""
        self.assertNotIn("-t", self.argv)

    def test_the_cuda_device_is_opened(self):
        self.assertIn("-init_hw_device", self.argv)
        self.assertEqual(flag_value(self.argv, "-filter_hw_device"), "cu")


class TestPreviewWindow(unittest.TestCase):
    def test_sized_at_birth_in_physical_pixels(self):
        """-x/-y are physical; only the dispatcher's coordinates are logical."""
        argv = pipeline.ffplay_argv("/run/preview.fifo")
        width, height = config.hud_size()
        self.assertEqual(flag_value(argv, "-x"), str(width))
        self.assertEqual(flag_value(argv, "-y"), str(height))
        self.assertNotEqual(flag_value(argv, "-x"), str(config.to_logical(width)))
        self.assertIn("-noborder", argv)

    def test_titled_so_the_dispatcher_can_find_it(self):
        self.assertEqual(flag_value(pipeline.ffplay_argv("/f"), "-window_title"), pipeline.PREVIEW_TITLE)

    def test_runs_without_buffering(self):
        self.assertIn("-fflags nobuffer", " ".join(pipeline.ffplay_argv("/f")))


class TestPlacement(unittest.TestCase):
    def test_moves_the_window_under_the_circle_in_logical_coordinates(self):
        commands = pipeline.placement_dispatches()
        joined = "\n".join(commands)
        self.assertIn("relative = false", joined)
        self.assertIn("hl.dsp.window.float", joined)
        self.assertIn("hl.dsp.window.pin", joined)
        physical_x, physical_y = config.hud_position()
        self.assertIn(f"x = {config.to_logical(physical_x)}", joined)
        self.assertIn(f"y = {config.to_logical(physical_y)}", joined)

    def test_the_window_stays_inside_the_circles_inscribed_square(self):
        inscribed = int(config.CIRCLE_DIAMETER / (2 ** 0.5))
        width, height = config.hud_size()
        self.assertLessEqual(width, inscribed)
        self.assertLessEqual(height, inscribed)
        x, y = config.hud_position()
        circle_x, circle_y = config.circle_position()
        self.assertGreaterEqual(x, circle_x + (config.CIRCLE_DIAMETER - inscribed) // 2)
        self.assertGreaterEqual(y, circle_y + (config.CIRCLE_DIAMETER - inscribed) // 2)


class TestMeter(unittest.TestCase):
    def test_reads_peak_level_off_the_same_source_the_take_holds(self):
        argv = pipeline.meter_argv("mic-source")
        joined = " ".join(argv)
        self.assertIn("astats", joined)
        self.assertIn("Overall.Peak_level", joined)
        self.assertIn("mic-source", argv)


if __name__ == "__main__":
    unittest.main()
