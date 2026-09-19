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
