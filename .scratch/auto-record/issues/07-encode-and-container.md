# NVENC settings and a container for two audio tracks

Type: grilling
Status: resolved

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

**From ticket 06** (measured here): **mkv survives SIGKILL** — 3439/3442 frames recovered, only
a `File ended prematurely` warning. The shutdown ladder settled there (SIGINT → 10s → SIGTERM →
3s → SIGKILL) has a SIGKILL rung *because* of that, so choosing mp4 as the written container
would remove the pipeline's only crash guarantee, not just risk one case. Ticket 06 also fixed
the **output rate at 50 fps**, not 60, and the file is written as `<timestamp> UNTITLED.mkv`
directly into `/home/s1n7ax/Videos/Youtube/00 new/`.

## Resolution

Everything below was measured on the real desktop (GTX 1060, ffmpeg 6.1.6), not reasoned about.
Scripts and logs: `research/07-encode-measurements/`.

### The settings

```
-c:v h264_nvenc -preset p4 -tune hq -rc vbr -cq 23 -b:v 0 \
  -pix_fmt yuv420p -g 100 -bf 3 -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 \
  -fps_mode cfr -r 50
```

Three AAC tracks, in this order:

| track | content | codec | why |
|---|---|---|---|
| 0 | mic + desktop mixed | AAC 192k stereo | the one track YouTube reads |
| 1 | mic only | AAC 96k **mono** | untouched, for a re-mix |
| 2 | desktop only | AAC 192k stereo | untouched, for a re-mix |

```
[mic][desk]amix=inputs=2:normalize=0:weights=1 0.35[mix]
-metadata:s:a:0 title=Mix        -metadata:s:a:0 handler_name=Mix
-metadata:s:a:1 title=Mic        -metadata:s:a:1 handler_name=Mic
-metadata:s:a:2 title=Desktop    -metadata:s:a:2 handler_name=Desktop
```

Container stays **mkv** (ticket 06's SIGKILL guarantee), 50 fps (ticket 06).

### `yuv420p` is forced, not chosen

`overlay_cuda` **rejects 4:4:4 outright**:

```
[overlay_cuda] Unsupported main input format: yuv444p
[Parsed_overlay_cuda_3] Failed to configure output pad
```

4:4:4 would mean abandoning the GPU overlay path entirely, so the text-sharpness question is
closed by the filter, not by taste. (For the record 4:4:4 also cost **2.5x the bitrate** on the
text probe — 7104 vs 2824 kbit/s.) YouTube converts to 4:2:0 on ingest regardless.

### H.264 beats HEVC on this GPU — the old OBS profile was wrong here

The previous OBS profile used `jim_hevc_nvenc`. On Pascal that is the worse choice on **both**
axes. Matched CQ, real desktop text, against a lossless yuv420p reference:

| | cq 19 | cq 23 | cq 27 |
|---|---|---|---|
| `h264_nvenc` | 1682 kbit/s · 61.2 dB | 1308 · **58.0** | 1013 · 54.7 |
| `hevc_nvenc` | **1861** kbit/s · **57.9** dB | 1441 · 57.7 | 1072 · 55.9 |

H.264 reaches 58.0 dB at 1308 kbit/s; HEVC needs 1861 kbit/s for 57.9 dB — **~30% less
efficient**. Pascal's HEVC encoder also **hard-fails on `-bf 3`**:

```
hevc_nvenc -bf 3  -> Error while filtering: Generic error in an external library
hevc_nvenc -bf 0  -> OK
```

Pascal HEVC has no B-frames (they arrive with Turing). H.264's B-frames are worth ~4%
(`-bf 0` 1360 kbit/s @ 57.77 dB vs `-bf 3` 1308 @ 58.01), so they are not the whole 30% —
Pascal's HEVC encoder is simply weaker. `-bf 3` is the sweet spot; `-bf 2` and `-bf 4` both
came out *larger*.

> An earlier SSIM sweep over the synthetic scroll source showed quality flat across cq 17-28.
> That was an **artifact**: `-bf 3` reorders frames, and a 1-frame offset against a 444 px/s
> scroll shifts the image ~9 px, collapsing SSIM to a constant ~0.962 regardless of QP. The
> table above avoids it by measuring on a near-static real capture. Don't trust
> `run2.log`/`rc.sh` SSIM numbers.

### CQ 23, no bitrate cap

`-rc vbr -cq 23 -b:v 0`. At 58 dB PSNR this is visually lossless on text, and a cap is exactly
what would soften text during a scroll. Size follows content by design: the real static desktop
measured **~1.3-2.0 Mbit/s**, the synthetic text scroll 2.8 Mbit/s at cq 21. Mixed content with
video playback will be several times that; nothing in the pipeline needs to care.

### `-g 100` — 2-second trim granularity

LosslessCut's lossless cuts snap to keyframes, so the GOP *is* the trim granularity. Real
content at cq 23:

| keyframes | bitrate | 40-min take |
|---|---|---|
| `-g 50` (1 s) | 1884 kbit/s | 565 MB |
| `-g 100` (2 s) | 1308 kbit/s | 393 MB |
| `-g 250` (5 s) | 1033 kbit/s | 310 MB |

1 s granularity costs **+82%**, 2 s costs **+27%** over NVENC's 250-frame default. 2 s is the
balance: fine enough to cut where you meant to, and the absolute sizes are small either way.

### Three tracks, because YouTube reads one

A plain YouTube upload consumes **one** audio track, and LosslessCut can drop or keep tracks but
cannot *mix* them. "Two tracks, never mixed" (settled at charting) and "YouTube-uploadable after
a trim in LosslessCut" (the destination) therefore had **no step joining them** — the route had
a hole. Track 0 closes it; tracks 1 and 2 keep the charted decision intact.

`normalize=0` is required: `amix` divides by input count by default, measured at exactly 6 dB
down (mean −24.1 dB vs −18.1 dB). `weights=1 0.35` puts desktop audio ~9 dB under the mic. No
limiter — tracks 1 and 2 are pristine, so a bad mix is always recoverable, and a limiter would
make track 0 look irreversible when it isn't.

### AAC, and mono for the mic

ffmpeg 6.1 muxes AAC, FLAC, Opus **and** PCM into both mkv and mp4 (measured), so the container
does not force the codec. AAC anyway: the desktop track is already a lossy Bluetooth codec, so
lossless capture of it preserves nothing, and YouTube's ingest of Opus/FLAC-in-mp4 is far less
trodden.

The mic goes to **mono**. Its two channels track each other to within 16 dB (L−R peak −55.8 dB
against a −40 dBFS room) — one capsule duplicated to stereo, so 192 kbit/s of the same signal
twice. Measured on a quiet room, so this is a strong hint rather than proof; verify on a take
with real speech.

### Track labels survive the mp4 export

`title` tags survive in mkv but are **lost on mp4 export** — mp4 has no title tag, ffmpeg falls
back to `handler_name=SoundHandler` (measured). Setting `handler_name` as well keeps the tracks
labelled after LosslessCut exports.

### Throughput of the final bundle

The whole graph — `hwupload_cuda → overlay_cuda → h264_nvenc` at the settings above — runs
**111 fps** at 3440x1440 (300 frames in 2.71 s), **2.2x headroom at 50 fps**. Consistent with
ticket 14. Preset `p4`: on the text probe `p7` was 0.07% smaller for 9% more time, so the slower
preset ticket 14 said was affordable turns out to buy nothing.

### Left to other tickets

- The **mic level meter** during preflight — ticket 15.
- Which node the desktop audio actually comes from — ticket 16.
- Mic **noise suppression** — still fog; this ticket touches gain and channel count, nothing else.
