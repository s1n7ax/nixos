# Screen capture into ffmpeg on Hyprland + NVIDIA

Type: research
Status: resolved

## Question

How does a 3440x1440 Hyprland screen reach an ffmpeg filter graph on this NVIDIA machine?

Compare `wf-recorder`, `wl-screenrec`, and the xdg-desktop-portal / PipeWire route (`pipewiresrc`, or ffmpeg's portal support):

- Which can hand ffmpeg a *filterable* raw stream — usable as an input that a later `overlay` filter draws onto — rather than only writing its own encoded file?
- Which work on NVIDIA proprietary (legacy_580) under Hyprland, and which need `wlr-screencopy` support the compositor may or may not expose?
- Frame rate and dropped frames at 3440x1440 — the monitor runs 144Hz; what capture rate is sustainable?
- NVENC path: can capture stay on the GPU end to end, or does each frame round-trip through system memory?
- Does the chosen route need a portal permission dialog every run (which would break unattended start)?

Answer decides the head of the pipeline and constrains tickets 04, 05, 07.

## Answer

Findings: [research/02-wayland-screen-capture.md](../research/02-wayland-screen-capture.md) (825 lines, every claim cited to a primary source).

- **`wl-screenrec` is dead on this machine.** It requires VAAPI *encode*; `nvidia-vaapi-driver`'s own README says decoding only, encoding is not supported, and its issue #79 is this exact Hyprland + NVIDIA failure with the maintainer confirming there is no VAAPI encode driver for NVIDIA. `--no-hw` does not save it — the capture-side frame context is VAAPI too.
- **The portal route needs a GStreamer bridge**, because ffmpeg has no PipeWire input at all — verified three ways: no `pipewire*` in `libavdevice/`, no `vsrc_pipewiregrab.c` in `libavfilter/`, and `ffmpeg -devices` lists only `kmsgrab/v4l2/x11grab/lavfi`. `kmsgrab` is also out: it needs DRM master or `CAP_SYS_ADMIN`, and Hyprland holds DRM master.
- **`wf-recorder` is the only viable route.** Hyprland implements `wlr-screencopy` (`src/protocols/Screencopy.cpp`), wf-recorder only initialises VAAPI when the codec name contains `vaapi`, and it writes through `avio_open()` so `--file pipe:1` is a legal raw-frame output. Two traps in its source: the overwrite prompt fires on FIFOs but not on `pipe:1`, and `-r` is what makes output CFR — mandatory, since rawvideo over a pipe carries no timestamps.
- **Nothing stays on the GPU end to end.** `hwcontext_cuda.c`'s `cuda_device_derive` only supports deriving from Vulkan, so there is no DRM→CUDA import path; every frame round-trips system memory once, about 1.19 GB/s per leg at 3440x1440 bgr0 @60 — under 10% of PCIe 3.0 x16. After one `hwupload_cuda`, the chain `scale_cuda → overlay_cuda → h264_nvenc` stays on-GPU.
- **The GPU is a GTX 1060**: 12 NVENC sessions, H.264 and HEVC yes, **AV1 no** despite `av1_nvenc` existing in the build. Constrains ticket 07.
- **Hard constraint for ticket 04**: `overlay_cuda`'s main input must be **yuv420p**, not nv12, for the overlay to carry alpha.
- **Recommended invocation** (ffmpeg half smoke-tested; the CUDA leg could not be — the research sandbox has no `/dev/nvidia*`):

      wf-recorder --output DP-1 --framerate 60 --codec rawvideo --muxer rawvideo \
        --pixel-format bgr0 --file pipe:1 |
      ffmpeg -thread_queue_size 512 -f rawvideo -pixel_format bgr0 \
        -video_size 3440x1440 -framerate 60 -i pipe:0 …

  60 fps is the sustainable target; 144 is the ceiling, and capture is a serial request/reply bound to Hyprland's repaint.

Status: resolved
