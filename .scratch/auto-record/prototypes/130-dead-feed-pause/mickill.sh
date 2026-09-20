#!/usr/bin/env bash
# Kill the stand-in mic the way a USB mic unplug looks to a client: the
# PipeWire node simply disappears. Kill the feeder by pid, never by pattern -
# every wrapper shell in the test carries the pattern on its command line too.
# Unload by module NAME so stale instances from earlier runs go too: a single
# leftover null sink keeps the node alive and the test measures nothing.
kill "$(cat /tmp/p130-feeder.pid)" 2>/dev/null
pactl unload-module module-null-sink 2>/dev/null
