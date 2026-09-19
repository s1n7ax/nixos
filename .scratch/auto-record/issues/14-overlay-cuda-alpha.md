# Does overlay_cuda carry alpha on the GTX 1060?

Type: task
Status: open

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
