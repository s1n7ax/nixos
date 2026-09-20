#!/usr/bin/env bash
# The real camera-connect path for #131, minus the `sudo modprobe` line:
# v4l2loopback is already loaded, and sudo needs a password this rig cannot
# answer with its stdio closed. Everything else is byte-for-byte what
# system/home-manager/applications/scripts.nix installs as `camera-connect`.
#
# Logs every line with a monotonic-ish timestamp so the gphoto2 startup can be
# split from the ffmpeg startup after the fact.
set -uo pipefail

stamp() { while IFS= read -r line; do printf '%s %s\n' "$(date +%s.%N)" "$line"; done; }

printf '%s START realcam\n' "$(date +%s.%N)" >&2

gphoto2 \
	--stdout \
	--set-config viewfinder=1 \
	--capture-movie 2> >(stamp >&2) |
	ffmpeg \
		-i - \
		-vcodec copy \
		-threads 1 \
		-f v4l2 \
		"/dev/$(ls -1 /sys/devices/virtual/video4linux)" 2> >(stamp >&2)
