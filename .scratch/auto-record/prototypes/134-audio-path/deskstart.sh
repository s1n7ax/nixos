#!/usr/bin/env bash
# The stand-in desktop-audio sink: a null sink with a 660Hz tone playing into
# it, so the monitor carries something audiocheck.py can tell apart from the
# mic's 440Hz. Made the default sink, because the recorder captures desktop
# audio by following the default rather than pinning a serial.
pactl load-module module-null-sink sink_name=proto134desk \
  sink_properties=device.description=proto134desk > /tmp/p134-desk.module
wpctl set-default "$(pw-dump | jq -r '.[]|select(.type=="PipeWire:Interface:Node")|select(.info.props["node.name"]=="proto134desk")|.id')"
setsid gst-launch-1.0 -q audiotestsrc wave=sine freq=660 volume=0.05 \
  is-live=true ! audioconvert ! pulsesink device=proto134desk \
  >/tmp/p134-deskfeeder.log 2>&1 &
echo $! > /tmp/p134-deskfeeder.pid
