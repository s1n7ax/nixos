#!/usr/bin/env bash
cd "$(dirname "$0")"
setsid nohup ./fakecam.sh >/tmp/p130-fakecam.log 2>&1 &
