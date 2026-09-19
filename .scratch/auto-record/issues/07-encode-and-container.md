# NVENC settings and a container for two audio tracks

Type: grilling
Status: open

## Question

- Which NVENC encoder on legacy_580 — `h264_nvenc` or `hevc_nvenc`? The old OBS profile used `jim_hevc_nvenc`; HEVC is smaller but LosslessCut and YouTube handling differ.
- Bitrate / CQ target for 3440x1440 screen content, where text sharpness matters more than motion.
- Container: mkv survives a crash mid-write; mp4 does not but is what YouTube wants. Does the pipeline write mkv and let LosslessCut export mp4, or write mp4 and risk the crash case?
- Two audio tracks: which containers carry them, and does LosslessCut keep both through a trim?
- Capture frame rate versus encode frame rate — the screen is 144Hz, the camera is far slower (ticket 01). What single output rate?

Use `/grilling`.

**From ticket 02**: the GPU is a GTX 1060 — 12 NVENC sessions, H.264 and HEVC available, **AV1 not**, despite `av1_nvenc` existing in the ffmpeg build. Capture target is 60 fps.

**From ticket 14**: `h264_nvenc -preset p4 -tune hq -rc vbr -cq 23` at 3440x1440 runs at ~140 fps
unthrottled on this 1060 — 2.3x headroom at 60 fps. **NVENC is the pipeline's throughput ceiling**,
not the overlay, so a slower/higher-quality preset is affordable and `hevc_nvenc` should be
measured the same way before choosing. Encoding was measured with H.264; HEVC costs more.
