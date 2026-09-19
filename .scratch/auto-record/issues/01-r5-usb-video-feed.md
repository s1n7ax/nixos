# R5 over USB: what feed can we actually get?

Type: research
Status: resolved

## Question

What video feed can a Canon EOS R5 deliver to Linux over USB, and what are its limits?

- `gphoto2 --capture-movie` (what `camera-connect` in `system/home-manager/applications/scripts.nix:224` uses): what resolution and frame rate does the R5 actually output, what pixel format / codec arrives on stdout, and does `-vcodec copy` into v4l2loopback hold up or must it be transcoded?
- Hard limits: clip-length cap, overheating shutdown, auto power-off, and whether the camera drops the stream after N minutes.
- Does the R5 expose a native UVC webcam mode over USB that Linux picks up as a plain `/dev/video*` without gphoto2 and without v4l2loopback? If so, at what resolution and fps, and how does it compare?
- Does the feed carry the clean output (no focus boxes, no overlays), and is that a camera setting?

Answer decides whether the pipeline keeps the gphoto2 + v4l2loopback hop at all, and what resolution the circle overlay is sourced from.

## Answer

Findings: [research/01-r5-usb-video-feed.md](../research/01-r5-usb-video-feed.md) (534 lines, cited to libgphoto2 / ffmpeg / kernel / v4l2loopback source and Canon's own manual and firmware pages).

- **The R5 has no native UVC mode.** Canon's full published firmware history (1.1.1 → 2.2.0) never mentions UVC or UAC, the manual has no streaming page — unlike the R5 Mark II, R50 V and R6 Mark III, which do — and EOS Webcam Utility is Windows/macOS only. The kernel was never the blocker: `uvcvideo` binds by generic class. So gphoto2 stays.
- **`--capture-movie` is the polled PTP live view**, not the recorded movie: `action_camera_capture_movie()` loops `gp_camera_capture_preview()` and writes concatenated baseline JPEGs — an MJPEG elementary stream with no container and no timestamps. Expect roughly 1024×576 in movie mode at an unpaced ~10–25 fps. The R5's exact geometry and fps is the one thing no primary source confirms; the findings give two verification commands, now ticket 12.
- **`-vcodec copy` into v4l2loopback works mechanically** (MJPEG → `V4L2_PIX_FMT_MJPEG`), but ffmpeg's raw demuxer hard-defaults to `framerate=25` with `AVFMT_NOTIMESTAMPS`. The timing is fabricated — a direct sync hazard against screen capture plus two audio tracks. Feeds ticket 06.
- **Two live bugs in `camera-connect`** (`system/home-manager/applications/scripts.nix:224`): `max_buffer=2` is not a v4l2loopback parameter — the real one is `max_buffers`, already defaulting to 2 — so under `set -euo pipefail` the script dies at modprobe; and `ls /sys/devices/virtual/video4linux` picks the wrong node as soon as more than one virtual device exists.
- **Limits**: no clip cap on live view (29:59 is card-recording only), but Canon documents that extended Live View itself drives the thermal auto-shutdown. Mitigate with `Auto pwr off temp.=High`, `Standby: Low res.=On`, and no card inserted. gphoto2 defeats auto-power-off via `KeepDeviceOn`, after which the R5 ignores its own power-saving menu and draws ~10 W. USB-C cannot power the body — mains means AC-E6N + DR-E6. Now ticket 13.

**Recommendation**: pipe gphoto2 straight into the compositing ffmpeg and drop the v4l2loopback hop entirely. HDMI plus a capture dongle stays the documented fallback if the live-view resolution proves too low.

Status: resolved
