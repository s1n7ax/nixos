#!/usr/bin/env bash
# SIGKILL the real gphoto2 producer by exact process name: #127 found an
# unclean stop wedges the camera PTP session until `gphoto2 --reset`.
# Matching on the command line instead kills every wrapper shell in the test.
pkill -KILL -x gphoto2
