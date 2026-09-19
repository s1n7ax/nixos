# Automated screen + camera recording

Label: wayfinder:map

## Destination

A single `record` command, declared in this repo, that captures the 3440x1440 screen plus the Canon R5 over USB plus mic and desktop audio, live-composites the camera as a circle overlay, previews the feeds before and during the take, and writes one NVENC-encoded file to `/home/s1n7ax/Videos/Youtube/00 new/<timestamp> <description>`. The file is YouTube-uploadable after a trim in LosslessCut. No OBS, no kdenlive.

## Notes

- Domain: NixOS + home-manager config repo. Hyprland/Wayland, NVIDIA (legacy_580), PipeWire, single 3440x1440@144 monitor at scale 1.25.
- Every session: consult `/grilling` and `/domain-modeling`. Prototypes via `/prototype`, research via `/research`.
- Settled during charting:
  - Drop OBS entirely — one ffmpeg pipeline, nothing to configure by hand.
  - Record native 3440x1440; never crop or pad for 16:9.
  - Mic and desktop audio as two separate tracks, never mixed.
  - Preview both before the take (with a mic level meter, Enter to start) and during it.
  - Foreground process; Ctrl-C stops the take, then prompts for the description and renames the temp file. Timestamp format `2026-09-19 14-30-05`.
  - Trim by hand afterwards in LosslessCut — no re-encode, exports mp4.
- Planning map: tickets resolve decisions. The build happens after the map is clear.
- Hardware facts surfaced while charting: GPU is a **GTX 1060** — H.264 and HEVC via NVENC, no AV1. The R5 has **no UVC mode**; gphoto2 PTP live view is the only USB feed.

## Decisions so far

<!-- one line per closed ticket -->

- [R5 over USB: what feed can we actually get?](issues/01-r5-usb-video-feed.md) — no native UVC on the R5, so gphoto2 stays; `--capture-movie` is polled PTP live view emitting untimestamped MJPEG at roughly 1024x576, unpaced ~10-25 fps; pipe it straight into the compositing ffmpeg and drop the v4l2loopback hop.
- [Screen capture into ffmpeg on Hyprland + NVIDIA](issues/02-wayland-screen-capture-into-ffmpeg.md) — `wf-recorder --codec rawvideo --file pipe:1` is the only viable route (wl-screenrec needs VAAPI encode, which NVIDIA lacks; ffmpeg has no PipeWire input; kmsgrab needs DRM master); one unavoidable system-memory round-trip, then `hwupload_cuda → overlay_cuda → h264_nvenc` stays on-GPU at 60 fps.
- [Addressing mic and desktop audio from ffmpeg](issues/03-pipewire-source-addressing.md) — `-f pulse` is the only route (ffmpeg has no PipeWire input); desktop audio via `@DEFAULT_MONITOR@` or a resolved `pactl get-default-sink` + `.monitor`; the mic must be pinned to a concrete node name or a headset plugged in mid-take silently takes over; concurrent metering during recording is safe.

## Not yet specified

- Recording-in-progress indicator — whether the take needs a visible "you are recording" signal, and where it lives so it stays out of the capture.
- What happens to the description prompt when a take crashes or the machine dies mid-record.
- Multi-take sessions: several takes back to back without re-running preflight each time.
- Mic noise suppression / gain — whether the pipeline should touch audio at all before writing it.
- Camera framing adjustment mid-take.
- Hyprland's `screencopy` permission now defaults to ASK and would prompt `wf-recorder` on every run — inert today only because this repo never sets `ecosystem.enforce_permissions`. Whether to pin that explicitly so a future Hyprland update cannot break unattended recording.
- HDMI plus a capture dongle as the fallback path, if the R5's live-view resolution (ticket 12) proves too low to be worth overlaying.

## Out of scope

- The trim itself — done by hand in LosslessCut.
- Thumbnails.
- Uploading to YouTube.
