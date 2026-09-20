#!/usr/bin/env bash
# realcam.sh with ffmpeg's MJPEG probe cut short. The measurement in #131 put
# ~570 ms of camera-connect's ~730 ms return time inside ffmpeg's format probe
# (`Format mjpeg detected only with low score of 25`), not inside gphoto2's PTP
# startup, which takes ~140 ms. The format is known, so tell ffmpeg instead of
# letting it guess.
set -uo pipefail

stamp() { while IFS= read -r line; do printf '%s %s\n' "$(date +%s.%N)" "$line"; done; }

printf '%s START realcam-fast\n' "$(date +%s.%N)" >&2

gphoto2 \
	--stdout \
	--set-config viewfinder=1 \
	--capture-movie 2> >(stamp >&2) |
	ffmpeg \
		-f mjpeg -probesize 32 -analyzeduration 0 -fflags nobuffer \
		-i - \
		-vcodec copy \
		-threads 1 \
		-f v4l2 \
		"/dev/$(ls -1 /sys/devices/virtual/video4linux)" 2> >(stamp >&2)
