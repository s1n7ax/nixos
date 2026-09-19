"""Resolving the two sources, refusing the wrong one, and noticing the move."""

from __future__ import annotations

import json
import unittest

import audio

METADATA = (
    'Found "default" metadata 40\n'
    "update: id:0 key:'default.configured.audio.sink' value:'{\"name\":\"\"}' type:'Spa:String:JSON'\n"
    "update: id:0 key:'default.audio.sink' value:'{\"name\":\"bluez_output.58_18_62_1F_32_D3.1\"}'"
    " type:'Spa:String:JSON'\n"
    "update: id:0 key:'default.audio.source'"
    " value:'{\"name\":\"alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo\"}'"
    " type:'Spa:String:JSON'\n"
)


def node(node_id, name, media_class, pid=None, media_name=None):
    props = {"node.name": name, "media.class": media_class}
    if pid is not None:
        props["application.process.id"] = pid
    if media_name is not None:
        props["media.name"] = media_name
    return {"id": node_id, "type": "PipeWire:Interface:Node", "info": {"props": props}}


def link(link_id, output_node, input_node):
    return {
        "id": link_id,
        "type": "PipeWire:Interface:Link",
        "info": {"output-node-id": output_node, "input-node-id": input_node, "props": {}},
    }


class TestDefaultSink(unittest.TestCase):
    def test_reads_the_default_sink(self):
        self.assertEqual(audio.parse_default_sink(METADATA), "bluez_output.58_18_62_1F_32_D3.1")

    def test_ignores_the_configured_sink(self):
        """A configured default that doesn't exist falls through anyway, so it is not read."""
        self.assertNotEqual(audio.parse_default_sink(METADATA), "")

    def test_no_default_at_all(self):
        self.assertIsNone(audio.parse_default_sink('Found "default" metadata 40\n'))


class TestDesktopSource(unittest.TestCase):
    def test_desktop_audio_is_the_default_sink_monitor(self):
        self.assertEqual(
            audio.monitor_of("bluez_output.58_18_62_1F_32_D3.1"),
            "bluez_output.58_18_62_1F_32_D3.1.monitor",
        )

    def test_a_name_that_is_already_a_monitor_is_left_alone(self):
        self.assertEqual(audio.monitor_of("x.monitor"), "x.monitor")

    def test_the_gpu_hdmi_fallthrough_is_refused(self):
        self.assertTrue(audio.is_blocked("alsa_output.pci-0000_05_00.1.pro-output-3.monitor"))
        self.assertTrue(audio.is_blocked("alsa_output.pci-0000_05_00.1.pro-output-7.monitor"))

    def test_the_headset_monitor_is_allowed(self):
        self.assertFalse(audio.is_blocked("bluez_output.58_18_62_1F_32_D3.1.monitor"))


class TestMicPresence(unittest.TestCase):
    def test_finds_the_pinned_mic(self):
        dump = json.dumps([node(46, audio.config.MIC_SOURCE, "Audio/Source")])
        self.assertTrue(audio.source_exists(dump, audio.config.MIC_SOURCE))

    def test_a_profile_switch_renames_it_away(self):
        renamed = audio.config.MIC_SOURCE.replace("analog-stereo", "iec958-stereo")
        dump = json.dumps([node(46, renamed, "Audio/Source")])
        self.assertFalse(audio.source_exists(dump, audio.config.MIC_SOURCE))

    def test_a_monitor_counts_as_present(self):
        dump = json.dumps([node(124, "bluez_output.58_18_62_1F_32_D3.1", "Audio/Sink")])
        self.assertTrue(audio.source_exists(dump, "bluez_output.58_18_62_1F_32_D3.1.monitor"))


class TestCaptureSources(unittest.TestCase):
    def test_maps_our_streams_to_what_feeds_them(self):
        dump = json.dumps(
            [
                node(46, "fifine", "Audio/Source"),
                node(124, "headset.monitor", "Audio/Source"),
                node(131, "Lavf", "Stream/Input/Audio", pid=900, media_name="record-mic"),
                node(132, "Lavf", "Stream/Input/Audio", pid=900, media_name="record-desktop"),
                node(140, "Lavf", "Stream/Input/Audio", pid=901, media_name="record-mic"),
                link(1, 46, 131),
                link(2, 124, 132),
                link(3, 46, 140),
            ]
        )
        self.assertEqual(
            audio.capture_sources(dump, 900),
            {"record-mic": "fifine", "record-desktop": "headset.monitor"},
        )

    def test_an_unlinked_stream_reports_nothing(self):
        dump = json.dumps([node(131, "Lavf", "Stream/Input/Audio", pid=900, media_name="record-mic")])
        self.assertEqual(audio.capture_sources(dump, 900), {"record-mic": None})


class TestMoves(unittest.TestCase):
    def test_a_swapped_source_is_a_move(self):
        before = {"record-desktop": "headset.monitor"}
        after = {"record-desktop": "alsa_output.pci-0000_05_00.1.pro-output-3.monitor"}
        self.assertEqual(
            audio.moves(before, after),
            [("record-desktop", "headset.monitor", "alsa_output.pci-0000_05_00.1.pro-output-3.monitor")],
        )

    def test_nothing_changing_is_not_a_move(self):
        snapshot = {"record-mic": "fifine", "record-desktop": "headset.monitor"}
        self.assertEqual(audio.moves(snapshot, snapshot), [])

    def test_a_stream_that_has_not_appeared_yet_is_not_a_move(self):
        self.assertEqual(audio.moves({"record-mic": None}, {"record-mic": "fifine"}), [])

    def test_a_stream_that_vanishes_from_the_dump_is_not_reported(self):
        self.assertEqual(audio.moves({"record-mic": "fifine"}, {}), [])


class TestWarning(unittest.TestCase):
    def test_reads_as_a_wall_clock_stamped_shout(self):
        line = audio.move_warning("00:14:22", "record-desktop", "headset.monitor", "gpu.monitor")
        self.assertEqual(line, "!! 00:14:22  record-desktop moved: headset.monitor -> gpu.monitor")


if __name__ == "__main__":
    unittest.main()
