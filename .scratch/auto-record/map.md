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
- Camera facts measured in ticket 12, on the real body: live view is **camera-paced, not poll-bound** — stills mode 960x640 3:2 @ 30 fps fixed, movie mode 1024x576 16:9 @ exactly the Movie rec quality rate (25.00P/50.00P/4K 25.00P all confirmed). Recording *resolution* never changes live-view geometry; only the rate follows. The feed carries **no overlays at all** and needs no menu setting to clean it.
- Desktop facts confirmed in ticket 05, the first ticket run on the real machine rather than `dev-vm`: Hyprland **0.55.4**, whose Lua dispatcher API replaced `hyprctl dispatch movewindowpixel exact ...`; `wf-recorder` and `pactl` are **not installed**; `wf-recorder` captures the full physical 3440x1440 despite the logical 2752x1152 region; the default sink is a **Bluetooth headset**. Ticket 11 then confirmed the audio names on the real machine and retired the `pactl` worry: nothing in the pipeline needs it.

## Decisions so far

<!-- one line per closed ticket -->

- [R5 over USB: what feed can we actually get?](issues/01-r5-usb-video-feed.md) — no native UVC on the R5, so gphoto2 stays; `--capture-movie` is polled PTP live view emitting untimestamped MJPEG at roughly 1024x576, unpaced ~10-25 fps; pipe it straight into the compositing ffmpeg and drop the v4l2loopback hop.
- [Screen capture into ffmpeg on Hyprland + NVIDIA](issues/02-wayland-screen-capture-into-ffmpeg.md) — `wf-recorder --codec rawvideo --file pipe:1` is the only viable route (wl-screenrec needs VAAPI encode, which NVIDIA lacks; ffmpeg has no PipeWire input; kmsgrab needs DRM master); one unavoidable system-memory round-trip, then `hwupload_cuda → overlay_cuda → h264_nvenc` stays on-GPU at 60 fps.
- [Addressing mic and desktop audio from ffmpeg](issues/03-pipewire-source-addressing.md) — `-f pulse` is the only route (ffmpeg has no PipeWire input); desktop audio via `@DEFAULT_MONITOR@` or a resolved `pactl get-default-sink` + `.monitor`; the mic must be pinned to a concrete node name or a headset plugged in mid-take silently takes over; concurrent metering during recording is safe.
- [The circle: how it looks and where it sits](issues/04-circle-overlay-prototype.md) — 540px circle, bottom-right at `overlay=2860:860`, 3px feather plus a 6px `#89b4fa` ring (the ring is required — with no ring the circle vanishes over a dark pane); mask is a static PNG through `alphamerge`, never `geq`, which benchmarked 8.3x more expensive and cannot hold 60 fps on CPU; all constants, no flags.
- [Preview that costs no frames](issues/05-live-preview-prototype.md) — the `split` branch costs **zero** dropped frames on both overlay paths (900/900 at 60 fps, measured on the real desktop); preview goes to a separate `ffplay` over `-f fifo` with `drop_pkts_on_overflow` and **never** `attempt_recovery` — a slow reader otherwise collapses the take to 3 fps and `attempt_recovery` hangs past SIGTERM; ffmpeg's `-f sdl` output silently never opens a window on Wayland; and the preview window hides inside the circle's **381px inscribed square**, where the overlay paints over it and it never reaches the file.
- [Does overlay_cuda carry alpha on the GTX 1060?](issues/14-overlay-cuda-alpha.md) — alpha survives and is genuinely blended: the composite is a feathered disc, not a 540x540 square (proved with pure-colour probes, 1.6% RMSE against the CPU reference), and `-v verbose` shows no `hwdownload` — `h264_nvenc` takes CUDA frames directly. Both paths are **NVENC-bound** at ~140 fps (2.3x headroom at 60); the GPU path wins on CPU given back (~2.2 ms/frame), not throughput, so the CPU `overlay` (~0.73 ms/frame here, not dev-vm's 18) stays a viable fallback.
- [Confirm the real audio source names on the desktop](issues/11-confirm-audio-device-names.md) — mic is `alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo`, desktop is `bluez_output.58_18_62_1F_32_D3.1.monitor` (both proved with a live `-f pulse` capture); no dedup counters — the `.1` is the profile's device index and survives an AAC/SBC/HFP switch; `pactl` is **not needed** (`pw-metadata -n default` covers preflight); but `@DEFAULT_MONITOR@` is unsafe here — with the headset off the default falls through to a GPU HDMI monitor nothing plays to, silently and at 8 channels → ticket 16.
- [Measure the R5's actual live-view stream](issues/12-measure-real-r5-stream.md) — stills mode is **960x640 3:2 @ 30.02 fps**, movie mode **1024x576 16:9 @ the Movie rec quality rate** (50.00P → 50.10 fps measured); baseline JPEG `yuvj422p`, ~96-118 KiB/frame, 19.7-42.7 Mbit/s; feed is clean of AF boxes, crop bars and info even with Servo AF on, so nothing to configure; `liveviewsize` must stay **Large** or the source quarters to 512x288; and libgphoto2 #567 is real — 1-2 stale-geometry frames after any mode change make ffmpeg's mjpeg demuxer **lock the whole take to the wrong size**, which `-probesize` cannot fix → ticket 06.

## Not yet specified

- What happens to the description prompt when a take crashes or the machine dies mid-record.
- Multi-take sessions: several takes back to back without re-running preflight each time.
- Mic noise suppression / gain — whether the pipeline should touch audio at all before writing it.
- Whether this repo should pin `default.configured.audio.sink` in its WirePlumber config rather than leave the default sink to WirePlumber's remembered-selection stack (ticket 11 found nothing is configured; ticket 16 may absorb this).
- Ring colour is hardcoded `#89b4fa` — whether it should track the system theme instead.
- Hyprland's `screencopy` permission now defaults to ASK and would prompt `wf-recorder` on every run — inert today only because this repo never sets `ecosystem.enforce_permissions`. Whether to pin that explicitly so a future Hyprland update cannot break unattended recording.
- HDMI plus a capture dongle as the fallback path. **Ticket 12 largely defused this**: 576-640px of source height into a 540px circle is near 1:1, not the severe upscale feared. Revisit only if the composited circle actually looks soft.
- Whether preflight should *drive* the camera into a known mode (movie + FHD 50.00P + `liveviewsize=Large`) over PTP rather than trusting whatever the menu was left on — ticket 12 showed every one of those is a silent take-ruiner if wrong, but `gphoto2` cannot set the Movie rec quality rate at all, so part of it can only ever be a preflight *check*.
- The camera tops out at 50 fps while screen capture runs at 60. Whether the take should just drop to 50 fps throughout rather than duplicate camera frames into a 60 fps timeline.

## Out of scope

- The trim itself — done by hand in LosslessCut.
- Thumbnails.
- Uploading to YouTube.
