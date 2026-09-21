#!/usr/bin/env bash
# Kill the stand-in mic the way a USB mic unplug looks to a client: the
# PipeWire node disappears while audio is still flowing through it.
#
# Order matters. Killing the sine feeder first leaves the monitor alive but
# silent for ~190ms before the node goes, and that silence lands in the file
# as a hole the recorder never caused - it measures the rig, not the seam.
pactl unload-module "$(cat /tmp/p134-mic.module)" 2>/dev/null
kill "$(cat /tmp/p134-micfeeder.pid)" 2>/dev/null
