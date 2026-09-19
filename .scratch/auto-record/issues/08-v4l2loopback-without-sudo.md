# Load v4l2loopback without an interactive sudo

Type: task
Status: closed (out of scope)
Blocked by: 06

## Question

`camera-connect` (`system/home-manager/applications/scripts.nix:224`) runs `sudo modprobe v4l2loopback exclusive_caps=1 max_buffer=2`, which blocks unattended start with a password prompt. `boot.extraModulePackages` already has the module (`system/nixos/core/boot.nix:5`).

Make the loopback device exist without interaction:

- `boot.kernelModules` plus a `boot.extraModprobeConfig` options line, so the device exists from boot; versus a narrow `security.sudo.extraRules` entry for just this modprobe.
- Whether the device node needs a stable name — the script currently does `ls -1 /sys/devices/virtual/video4linux` and takes whatever appears, which picks the wrong device if anything else registers one. `video_nr=` and `card_label=` pin it.
- Whether this ticket survives at all: if ticket 01 finds the R5 works as plain UVC, v4l2loopback is not needed.

Resolved when the module loads at boot with pinned options and the script can find the device by name. Record the device path and label in the answer.

## Closed — out of scope

Its own last bullet asked whether it survives, and ticket 06 answered: **no**. The pipeline is
one ffmpeg reading `gphoto2 --capture-movie` directly off a pipe, so no `v4l2loopback` device is
created, loaded, or named anywhere in `record`. Nothing here blocks the destination.

The residue is not this map's: the pre-existing `camera-connect`
(`system/home-manager/applications/scripts.nix:224`) still shells out to `sudo modprobe` and is
likely dead code once `record` lands. Deleting it is repo tidying, not wayfinding.
