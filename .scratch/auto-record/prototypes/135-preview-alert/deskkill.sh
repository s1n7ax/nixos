#!/usr/bin/env bash
# Take the desktop-audio sink away mid-recording - what turning off a
# bluetooth headset looks like to the capture.
pactl unload-module "$(cat /tmp/p134-desk.module)" 2>/dev/null
kill "$(cat /tmp/p134-deskfeeder.pid)" 2>/dev/null
