#!/usr/bin/env bash
# Recreate the stand-in mic: a null sink plus a sine feeding it, so its
# monitor never suspends. An unfed monitor delivers one buffer per ~450ms.
#
# Unloading is by MODULE INDEX, not by name: this rig runs a second null sink
# for desktop audio, and `unload-module module-null-sink` takes down every
# null sink at once.
pactl load-module module-null-sink sink_name=proto133mic \
  sink_properties=device.description=proto133mic > /tmp/p134-mic.module
setsid gst-launch-1.0 -q audiotestsrc wave=sine freq=440 volume=0.02 \
  is-live=true ! audioconvert ! pulsesink device=proto133mic \
  >/tmp/p134-micfeeder.log 2>&1 &
echo $! > /tmp/p134-micfeeder.pid
