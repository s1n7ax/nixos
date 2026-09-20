#!/usr/bin/env bash
# Stand-in for camera-connect: feeds /dev/video9 the same shape the R5 does
# (1024x576 MJPEG at 50 fps) so the producer can be killed and restarted
# without the camera being plugged in. #127 established that a dead V4L2
# producer looks identical whatever the producer is.
#
# Writes its pid to /tmp/p130-fakecam.pid. Kill it by that pid, never by
# pattern: every wrapper shell in the test carries the pattern too.
echo $$ > /tmp/p130-fakecam.pid
exec ffmpeg -loglevel error -re \
  -f lavfi -i "testsrc2=size=1024x576:rate=50" \
  -c:v mjpeg -q:v 5 -pix_fmt yuvj422p \
  -f v4l2 "${1:-/dev/video9}"
