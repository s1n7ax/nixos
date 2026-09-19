# Measure the R5's actual live-view stream

Type: task
Status: resolved

## Question

Ticket 01 established what `gphoto2 --capture-movie` *is* — polled PTP live view, concatenated baseline JPEGs — but no primary source states the R5's exact geometry and frame rate. The findings file gives two verification commands.

On the desktop, with the R5 connected:

- Actual pixel dimensions of the live-view frames, in movie mode and in stills mode (they differ).
- Actual sustained frame rate, measured over a minute or more rather than a burst.
- Whether the frames are baseline JPEG as expected, and their size.
- Whether the feed is clean — no focus box, no info overlay — and which menu setting controls that.

These numbers set the source resolution for the circle crop (ticket 04) and the output frame rate (ticket 07). Record them verbatim in the answer.

## Answer

Measured on the real desktop, R5 on USB, `gphoto2 2.5.32` / `ffmpeg 6.1.6`. Scripts and
sample frames: [research/12-r5-stream-measurements/](../research/12-r5-stream-measurements/).

**The two modes genuinely differ, and neither matches the research estimate.**

### Geometry and rate

| mode | `eosmovieswitch` | geometry | aspect | sustained fps |
| --- | --- | --- | --- | --- |
| **Stills** | `0` | **960x640** | 3:2 | **30.02**, fixed |
| **Movie** | `1` | **1024x576** | 16:9 | **= the Movie rec quality frame rate** |

Movie-mode rate tracks the menu setting exactly:

- FHD 25.00P → **25.04 fps** (1753 frames / 70.00 s)
- FHD 50.00P → **50.10 fps** (1503 / 30.00 s)
- 4K UHD 25.00P → **25.10 fps** (502 / 20.00 s)

Recording *resolution* never touches live view — 4K and FHD both emit 1024x576; only the
rate follows. Stills mode ignores the movie rate setting entirely: 30.02 fps measured with
the camera set to FHD 50.00P.

The research file's "roughly 1024x576 ... unpaced ~10–25 fps" is right on movie geometry
and **wrong on pacing**. This is a camera-paced stream, not PTP-round-trip-bound. Per-10s
buckets across 70 s: `24.9 25.0 25.0 25.0 25.0 25.0 25.0`. Inter-frame gap stdev 6.6 ms
(stills) / 9.5 ms (movie), and that figure still includes my 64 KiB chunk-read granularity.
Both 70 s movie runs returned *exactly* 1753 frames.

### Codec and size

Baseline JPEG (`SOF0`) on every frame, 3 components, **4:2:2** (`yuvj422p`, luma sampling
`2x1`), no restart interval, no container, no timestamps — as predicted.

- movie 1024x576, lit scene: ~96 KiB/frame → **19.7 Mbit/s** @25p, **42.7 Mbit/s** @50p
- stills 960x640, lit scene: ~118 KiB/frame → **29.0 Mbit/s** @30p
- lens cap on: **~176 KiB/frame** — sensor noise compresses *worse* than a real scene, so
  size the buffers for the dark case, not the lit one.

### The feed is clean, and there is no menu setting to find

Nothing is baked in. Verified against three separate overlay sources:

- Servo AF on and actively hunting → **no AF box** in the stream.
- Stills aspect set to `16:9` and to `1.6x` → stream is **still the full uncropped 3:2
  960x640**, no crop bars (`stills-16x9-set-still-uncropped.jpg`).
- LCD showing its normal info overlay (`output` = `TFT + PC`) → stream clean.

The overlays are drawn by the LCD compositor, not the PTP live-view path. There is nothing
to turn off.

`output=PC` (which would blank the LCD) **will not stick** — the R5 reports `TFT + PC` back
immediately. The panel cannot be blanked over PTP to save heat → feeds ticket 13.

### The libgphoto2 #567 geometry hazard is real and silently ruins a take

Reproduced exactly, and **it hits the production command shape**, not some exotic one.

After any live-view geometry change — a `liveviewsize` change *or* the photo/movie switch —
the camera emits one or two **stale-geometry frames at the head of the next stream**.
Measured after flipping the switch to Photo: frames `[0]` and `[1]` arrived as 1024x576,
frames `[2..834]` as 960x640.

ffmpeg's raw mjpeg demuxer **locks to the first frame's geometry and rescales everything
after it**:

```
ffprobe stills50.mjpg                            -> 1024x576   (833 of 835 frames are 960x640)
ffprobe -probesize 100M -analyzeduration 100M    -> 1024x576   (does NOT help)
ffprobe  after dropping the 2 leading frames     -> 960x640    (correct)
```

So a take started right after touching the mode switch is encoded at the wrong geometry for
its **entire length**, with no error and no warning. `-probesize` / `-analyzeduration` cannot
fix it: the demuxer locks unconditionally on frame 0.

**Mitigation for ticket 06**: drop leading frames before ffmpeg sees them, or pin geometry
with an explicit `-f mjpeg -video_size`. The hazard is purely transitional — three
back-to-back runs with nothing changed were 100% uniform (78/77/77 frames), so a throwaway
warm-up stream during preflight also clears it.

### `liveviewsize` is a real lever, and it was not on the best setting

`/main/capturesettings/liveviewsize` offers three choices but only two outputs:

- `0 Large` → **1024x576** (movie) / 960x640 (stills)
- `1 Medium` / `2 Small` → **512x288**, ~36 KiB/frame

It read an unresolvable `val 1` when I started. **I left it at `Large`.** Anything else
quarters the circle's source.

### Consequences for the map

- The circle's source is 960x640 or 1024x576, so the 540px circle (ticket 04) is a mild
  **upscale**, not the severe one feared: 576–640 px of height cropped to a 540 px circle is
  near 1:1. The HDMI-plus-dongle fog entry is **much less urgent** — but this is still a
  ~0.6 MP source.
- **Movie mode at FHD 50.00P is the best available feed**: 1024x576 @ 50 fps, and 16:9 means
  the centre-square crop for the circle wastes the least.
- Screen capture runs at 60 fps (ticket 05); the camera tops out at 50. That rate mismatch
  into `overlay_cuda` is ticket 06/07's problem.
- ffmpeg's hardcoded `framerate=25` default for raw mjpeg happens to match FHD 25.00P and is
  **wrong for every other setting**. It must be set explicitly.

**Camera left as**: `liveviewsize=Large`, `aspectratio=3:2`, photo/movie switch on **Photo**,
Movie rec quality on **FHD 50.00P** (changed from 25.00P during the sweep — restore if wanted).

Status: resolved
