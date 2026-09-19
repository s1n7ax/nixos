# Preview that costs no frames

Type: prototype
Status: resolved

## Question

You want both a preflight preview (composited frame plus a mic level meter, Enter to start) and a preview that stays up during the take.

- How does the composited stream reach a preview window without re-capturing — `tee` muxer, `split` filter to an `sdl`/`ffplay` output, or a second consumer of the same source?
- Does the preview window itself get captured by the screen capture? If so, how is that avoided — a dedicated Hyprland workspace, a special window rule, or a second monitor-less output?
- What does the mic meter look like, given the recording holds the source? (`ebur128` filter's on-screen meter, or a separate `pactl` read.)
- Frame cost measured, not guessed: does preview during the take drop recording frames at 3440x1440?

Use `/prototype`. Link the working preview invocation from this ticket.

## Answer

Prototyped on the **real desktop** (`s1n7ax`, Hyprland 0.55.4, GTX 1060, ffmpeg 6.1.6,
DP-3 3440x1440@144 scale 1.25) — the first ticket to run on the target hardware rather than
`dev-vm`. Prototype on branch `prototype/05-live-preview` at
`.scratch/auto-record/prototypes/05-live-preview/` (see its `README.md`).

Headline: **the preview branch itself is free. The preview *transport* is what can cost you
the whole take**, and the preview *window* is solved by hiding it under the circle.

### The preview branch costs zero frames

15 s takes, real `wf-recorder` capture of DP-3 at 3440x1440, `-r 60 -D`, into `h264_nvenc`:

| config | recorded frames | wall | steady fps |
|---|---|---|---|
| `cpu-none` — CPU overlay, no preview | 900/900 | 15.4 s | 59-60 |
| `cpu-tee` — CPU overlay + preview branch | 900/900 | 15.4 s | 59-60 |
| `gpu-none` — `overlay_cuda`, no preview | 900/900 | 15.4 s | 60 |
| `gpu-tee` — `overlay_cuda` + preview branch | 900/900 | 15.4 s | 60-61 |

A `split` off the composited stream, scaled to 860x360, costs nothing measurable on either
overlay path. Ticket 04's worry that the CPU overlay would blow the 16.7 ms budget does not
reproduce on this CPU — `cpu-none` holds 60 fps with ~4 cores busy.

### Reaching the preview: `ffplay` over a fifo-muxer pipe. Not `tee`, never `-f sdl`

**`-f sdl` is a silent no-op on Wayland.** A second output `-f sdl` inside the recording
ffmpeg accepted and consumed **408 MB** of frames across a 15 s take, exited `rc=0`, logged no
error — and **never opened a window**. Nothing to see, frames burned. `ffplay`, by contrast,
opens a real native Wayland window (`xwayland=false` in `hyprctl clients`), so the preview
consumer has to be a **separate process**.

That separation is what introduces the real risk, and the transport decides whether the take
survives it. Measured, 20 s takes, 1200 frames expected:

| preview reader | transport | recorded frames | outcome |
|---|---|---|---|
| dies at t+6s | plain fifo | 1200/1200 | fine — EPIPE kills only the preview output |
| dies at t+6s | `fifo` muxer + `attempt_recovery=1` | — | **hangs forever**, ignores SIGTERM, needs SIGKILL |
| too slow (64 KiB / 50 ms) | plain fifo | **207**/1200 | **take collapses to ~3 fps** |
| too slow | `fifo` muxer + `drop_pkts_on_overflow=1` | 1200/1200 | fine, 20.0 s |
| dies at t+6s | `fifo` + `drop_pkts_on_overflow=1`, **no** recovery | 1200/1200 | fine, playable |
| too slow | same | 1200/1200 | fine, 20.0 s |

The dangerous reader is the **slow** one, not the dead one: a dead reader gives ffmpeg an EPIPE
it handles cleanly, while a slow one fills the pipe and back-pressures the encoder through the
shared filter graph. `attempt_recovery` is actively harmful — it reopens a POSIX fifo for
write, which blocks until a reader appears, hanging the whole process past SIGTERM.

**Settled:**

```
-map "[pv]" -c:v rawvideo -f fifo -fifo_format nut \
  -queue_size 8 -drop_pkts_on_overflow 1 preview.fifo
```

with a separate `ffplay -fflags nobuffer -flags low_delay -i preview.fifo`. No
`attempt_recovery`, no `recover_any_error`. The preview is lossy by design; the take never is.

### The preview window IS captured — so park it under the circle

`wf-recorder -o DP-3` captures DP-3's composited image, so **anything visible on the only
monitor is in the recording** — demonstrated with a preview window plainly visible mid-frame in
a test capture. A headless output (`hyprctl output create headless` works, gives HEADLESS-2) or
a parked workspace keeps it out of the take, but also out of *your* sight, which defeats it.

The way out is that **ticket 04's circle is composited after capture**. The overlay paints a
540 px disc at physical `2860,860`; the largest square inscribed in it is 381 px. A preview
window parked inside that square is painted over by the overlay and never reaches the file.

Verified: a **340 px** orange window at the circle's centre, captured and cropped to exactly
its region — `under-circle-hidden-region.png` shows **only the camera**, no trace of the
window. Evidence frames `under-circle-zoom.png` and `under-circle-hidden-region.png`.

So the inscribed square is a **private HUD**: visible to you, invisible in the take. The
camera preview and the mic meter both belong there.

Placement — note Hyprland 0.55.4 replaced the dispatcher syntax with a Lua API, so
`hyprctl dispatch movewindowpixel exact ...` is gone and errors with "can't work with
non-legacy parsers":

```sh
hyprctl dispatch 'hl.dsp.window.float("title:rec-preview")'
hyprctl dispatch "hl.dsp.window.resize{ x = 272, y = 272, relative = false, window = 'title:rec-preview' }"
hyprctl dispatch "hl.dsp.window.move{ x = 2368, y = 768, relative = false, window = 'title:rec-preview' }"
hyprctl dispatch 'hl.dsp.window.pin("title:rec-preview")'
```

`relative = false` is required or the coordinates are treated as deltas. Dispatcher coordinates
are **logical** (physical ÷ 1.25); `ffplay -x/-y` are **physical**. Hyprland's `resize` would
not shrink the ffplay window below its native size, so size the window at birth with
`ffplay -x/-y -noborder` and only `move`/`pin` it afterwards.

### Mic meter: a second reader of the same source, ~20 updates/s

Ticket 03's claim that concurrent metering is safe is now verified on hardware: a 6.07 s wav
capture and a live meter read the same Fifine source at the same time without complaint.

```sh
ffmpeg -f pulse -i "$MIC" -af "astats=metadata=1:reset=1:measure_overall=Peak_level,\
ametadata=print:key=lavfi.astats.Overall.Peak_level:file=-" -f null -
```

`meter.sh` turns that into a terminal dB bar (room noise reads about -42 dB). Preflight it costs
nothing — the take has not started. During the take it must live in the under-circle HUD, since
the terminal it would otherwise print to is itself on screen and therefore in the recording.

### Still open — the one judgement call

The HUD is capped at **381 px** by the circle it hides under. Whether a preview that small,
showing camera plus meter, is worth having during the take — or whether preflight-only is
enough — is a preference, not a measurement. Raised as a new ticket.
