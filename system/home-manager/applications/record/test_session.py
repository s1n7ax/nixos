"""Preflight: what it refuses, and by which named error."""

from __future__ import annotations

import json
import unittest
from unittest import mock

import camera
import config
import errors
import session

HEADSET = "bluez_output.58_18_62_1F_32_D3.1"
GPU = "alsa_output.pci-0000_05_00.1.pro-output-3"


def metadata(sink: str) -> str:
    return f"update: id:0 key:'default.audio.sink' value:'{{\"name\":\"{sink}\"}}' type:'Spa:String:JSON'\n"


def dump(*names: str) -> str:
    return json.dumps(
        [{"id": i, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": name}}}
         for i, name in enumerate(names)]
    )


def good_probe() -> camera.Probe:
    return camera.Probe.of([(1024, 576)] * 50, [index * 0.04 for index in range(50)])


class Harness:
    """Stands in for the three helper binaries preflight shells out to."""

    def __init__(self, sink=HEADSET, nodes=(HEADSET, config.MIC_SOURCE), probe=None):
        self.sink, self.nodes, self.probe = sink, nodes, probe or good_probe()

    def run(self, argv):
        return metadata(self.sink) if argv[0] == "pw-metadata" else dump(*self.nodes)

    def apply(self):
        return (
            mock.patch.object(session, "_run", self.run),
            mock.patch.object(camera, "warm_up", lambda *_, **__: self.probe),
        )


def check_with(harness: Harness):
    runner, warmer = harness.apply()
    with runner, warmer:
        return session.check()


class TestPasses(unittest.TestCase):
    def test_a_ready_machine_reports_all_three_sources(self):
        preflight = check_with(Harness())
        self.assertEqual(preflight.mic, config.MIC_SOURCE)
        self.assertEqual(preflight.desktop, f"{HEADSET}.monitor")
        self.assertEqual(preflight.probe.geometry, (1024, 576))

    def test_the_summary_names_each_source(self):
        lines = check_with(Harness()).summary()
        self.assertIn("1024x576", lines[0])
        self.assertIn(config.MIC_SOURCE, lines[1])
        self.assertIn(f"{HEADSET}.monitor", lines[2])


class TestRefuses(unittest.TestCase):
    def test_the_gpu_hdmi_fallthrough(self):
        """With the headset off the default falls through to an output nothing plays to."""
        with self.assertRaises(errors.AudioSourceError) as raised:
            check_with(Harness(sink=GPU, nodes=(GPU, config.MIC_SOURCE)))
        self.assertIn("nothing plays to", str(raised.exception))

    def test_a_mic_renamed_by_a_profile_switch(self):
        renamed = config.MIC_SOURCE.replace("analog-stereo", "iec958-stereo")
        with self.assertRaises(errors.AudioSourceError) as raised:
            check_with(Harness(nodes=(HEADSET, renamed)))
        self.assertIn("input:analog-stereo", str(raised.exception))

    def test_no_default_sink_at_all(self):
        with mock.patch.object(session, "_run", lambda argv: ""):
            with self.assertRaises(errors.AudioSourceError):
                session.resolve_desktop()

    def test_a_camera_on_the_wrong_mode(self):
        stills = camera.Probe.of([(960, 640)] * 50, [index / 30 for index in range(50)])
        with self.assertRaises(errors.CameraNotReadyError) as raised:
            check_with(Harness(probe=stills))
        self.assertIn("Movie", str(raised.exception))

    def test_a_camera_that_is_not_there(self):
        with self.assertRaises(errors.CameraNotReadyError):
            check_with(Harness(probe=camera.Probe.of([], [])))

    def test_a_helper_binary_that_will_not_run(self):
        def explode(_argv):
            raise OSError("no such file")

        with mock.patch.object(session, "subprocess") as fake:
            fake.run.side_effect = OSError("no such file")
            fake.TimeoutExpired = TimeoutError
            with self.assertRaises(errors.ToolUnavailableError):
                session.resolve_desktop()


class TestErrorKinds(unittest.TestCase):
    def test_setup_problems_are_expected_and_the_machine_is_not(self):
        """The two kinds get different exit codes, so a caller can tell them apart."""
        self.assertTrue(issubclass(errors.AudioSourceError, errors.ExpectedError))
        self.assertTrue(issubclass(errors.CameraNotReadyError, errors.ExpectedError))
        self.assertTrue(issubclass(errors.ToolUnavailableError, errors.UnexpectedError))
        self.assertTrue(issubclass(errors.PipelineStartError, errors.UnexpectedError))


if __name__ == "__main__":
    unittest.main()
