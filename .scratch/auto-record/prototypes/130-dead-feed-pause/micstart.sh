#!/usr/bin/env bash
# Recreate the stand-in mic: a null sink plus a sine feeding it, so its
# monitor never suspends. An unfed monitor delivers one buffer per ~450ms.
pactl load-module module-null-sink sink_name=proto130mic \
  sink_properties=device.description=proto130mic > /tmp/p130-mic.module
setsid gst-launch-1.0 -q audiotestsrc wave=sine freq=440 volume=0.02 \
  is-live=true ! audioconvert ! pulsesink device=proto130mic \
  >/tmp/p130-feeder.log 2>&1 &
echo $! > /tmp/p130-feeder.pid
