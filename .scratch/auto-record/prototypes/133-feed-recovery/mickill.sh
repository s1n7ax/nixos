#!/usr/bin/env bash
# Kill the stand-in mic the way a USB mic unplug looks to a client: the
# PipeWire node disappears while audio is still flowing through it.
#
# Order matters. Killing the sine feeder first leaves the monitor alive but
# silent for ~190ms before the node goes, and that silence lands in the file
# as a hole the recorder never caused - it measures the rig, not the seam.
# Unload the sink first so the node dies mid-stream, then clean the feeder up.
pactl unload-module module-null-sink 2>/dev/null
kill "$(cat /tmp/p133-feeder.pid)" 2>/dev/null
