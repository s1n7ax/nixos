# Does overlay_cuda carry alpha on the GTX 1060?

Type: task
Status: resolved

## Question

Ticket 04 settled how the circle looks and proved the mask/alphamerge approach in **software**
on `dev-vm`, which has no GPU. The on-GPU half is untested.

Run on the desktop:

- Does `hwupload_cuda` accept the alpha-carrying circle (`yuva420p` / `rgba`), or does it
  refuse the format outright?
- Does `overlay_cuda` actually blend that alpha, or does it composite the full 540x540 square
  and lose the circle? Ticket 02 warns the **main** input must be `yuv420p`, not `nv12`.
- If alpha survives: confirm the whole chain stays on-GPU — no implicit `hwdownload` appears in
  `-v verbose` filter graph output.
- If it does not: measure the CPU `overlay` fallback at 3440x1440 with a 540px circle on the
  desktop CPU. dev-vm measured 18 ms/frame on 4 vCPUs, against a 16.7 ms budget at 60 fps.

The ffmpeg 6.1 build exposes no `format` or `alpha` option on `overlay_cuda`, so this cannot be
answered by inspection — it needs the hardware.

**Why it matters**: if alpha does not survive the GPU path, the composite has to come back to
system memory, which undoes the single-round-trip design ticket 02 established and changes what
ticket 06 can assume about the filter graph.

## Note from ticket 05 (not a resolution — the visual check is still owed)

Ran on the desktop while prototyping ticket 05. `hwupload_cuda` **does** accept the
alpha-carrying circle and `overlay_cuda` runs the whole 15 s take at 60 fps, 900/900 frames —
but only with all three of these, and the first failure looks like a hardware limitation when
it is not:

- `format=yuva420p` explicitly before `hwupload_cuda` on the overlay input.
- `format=yuv420p` explicitly before `hwupload_cuda` on the main input.
- **no `-pix_fmt` on the NVENC output.** `-pix_fmt yuv420p` inserts an `auto_scale` filter
  after `overlay_cuda` that CUDA frames cannot cross, and the error blames the filter:
  `Impossible to convert between the formats supported by the filter 'Parsed_overlay_cuda' and
  the filter 'auto_scale_1'`. That error cost an hour; it is a graph bug, not the GTX 1060.

Working chain (`run.sh gpu-none` in `.scratch/auto-record/prototypes/05-live-preview/`):

```
[cam]crop=576:576:224:0,scale=528:528,pad=540:540:6:6:0x89b4fa,format=rgba[c];
[mask]format=gray[m];[c][m]alphamerge[k];
[k]format=yuva420p,hwupload_cuda[kg];
[screen]format=yuv420p,hwupload_cuda[sg];
[sg][kg]overlay_cuda=x=2860:y=860
```

**Still owed by this ticket**: whether the alpha is actually *blended* — that the output shows
a feathered disc and not a 540x540 square — and whether `-v verbose` shows any implicit
`hwdownload`. Ticket 05 measured throughput, not pixels; its visual evidence frames came from
the **CPU** overlay path. Also worth noting for the fallback measurement this ticket asks for:
the CPU `overlay` path held 900/900 frames at 60 fps on this desktop CPU, so dev-vm's 18 ms/frame
does not reproduce here.

## Answer

**Alpha survives the GPU path, and it is genuinely blended.** The single-round-trip design
ticket 02 established holds; nothing about the filter graph has to change for ticket 06.

Run on the desktop — GTX 1060 6GB, driver 580.173.02, ffmpeg 6.1.6. Assets on branch
`prototype/14-overlay-cuda-alpha` at `.scratch/auto-record/prototypes/14-overlay-cuda-alpha/`
(see its `README.md` for the full tables).

### It blends the disc, not the square

Proved with deterministic colours rather than by eye: a pure-green `0x00FF00` background and a
pure-red `0xFF0000` camera stand-in through the exact ticket-04 chain. If `overlay_cuda`
composited the 540x540 **square**, its corners would read as the ring colour or the camera
colour. They read green — the background shows through:

| point | GPU | CPU reference |
| --- | --- | --- |
| corner + 3px (2863,863) | `0,254,0` green | `0,254,0` green |
| corner + 60px (2920,920) | `0,254,0` green | `0,254,0` green |
| disc centre (3130,1130) | `252,0,0` red | `252,0,0` red |

The feather survives too. Scanning the disc's left edge at row y=1130, both paths ramp green →
blend → ring `0x89B4FA` (137,177,250) → red over the same ~6px:

```
x=      2858        2860         2862          2864         2866
GPU   0,254,2    18,247,39   110,193,204   135,178,248   254,0,0
CPU   1,253,0    40,226,73   123,182,224   134,177,247   252,0,0
```

RMSE between the two 540x540 composites is **1.6%** — chroma-subsampling noise. The GPU's alpha
ramp is about one pixel steeper toward transparent at the outer edge; nothing else differs.
`real-circle-crop.png` is the same chain over a real `wf-recorder` capture (360/360 frames at
60 fps): a feathered disc with the ring, desktop visible in the corners.

### No implicit `hwdownload`

`-v verbose` on both the synthetic and the real run shows none. The encoder takes CUDA frames
straight from the filter:

```
[h264_nvenc] Using input frames context (format cuda) with h264_nvenc encoder.
  overlay_cuda:default -> Stream #0:0 (h264_nvenc)
```

Exactly one filter is auto-inserted, and it is **not** a round-trip:

```
auto-inserting filter 'auto_scale_0' between 'Parsed_alphamerge_5' and 'Parsed_format_6'
  w:540 h:540 fmt:rgba -> w:540 h:540 fmt:yuva420p
```

That is swscale performing the explicit `format=yuva420p`, on the CPU, on the 540x540 overlay,
*before* `hwupload_cuda` — once per camera frame at ~25 fps, not per screen frame at 60.

Ticket 05's three conditions all hold and all remain required: `format=yuva420p` before
`hwupload_cuda` on the overlay, `format=yuv420p` before it on the main input, and **no
`-pix_fmt` on the NVENC output**.

### The CPU fallback, measured anyway

Not needed, but the ticket asked and the number corrects dev-vm. 600 frames, unthrottled,
`h264_nvenc -preset p4 -tune hq -rc vbr -cq 23`:

| path | wall | fps | ms/frame | ffmpeg utime |
| --- | --- | --- | --- | --- |
| CPU `overlay` | 4.27 s | 140.5 | 7.12 | 2.78 s |
| `overlay_cuda` | 4.49 s | 133.5 | 7.49 | 1.48 s |

**Both paths are NVENC-bound, not overlay-bound** — 2.3x headroom over the 16.67 ms budget at
60 fps, and the two are within 5% of each other on wall time. With the encoder swapped out, the
CPU `overlay` itself costs **~0.73 ms/frame** at 3440x1440 with a 540px circle (0.96 ms against
a 0.23 ms no-overlay baseline), about 4% of the frame budget. dev-vm's 18 ms/frame was a
4-vCPU artefact and does not reproduce here.

So the GPU path is chosen for the **CPU it gives back** (~2.2 ms/frame, ~1.9x less), not for
throughput. That also means a CPU-overlay fallback stays viable if a future driver or ffmpeg
update breaks `overlay_cuda` — it is not a cliff.
