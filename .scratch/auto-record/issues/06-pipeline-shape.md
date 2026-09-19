# One ffmpeg, or a supervisor over several?

Type: grilling
Status: resolved

## Question

Is this one `ffmpeg` process with four inputs and a filter graph, or a small supervisor script running several processes?

- A/V sync: three sources (screen, camera, two audio) start at different moments and drift. Does a single ffmpeg with `-itsoffset` handle it, or does sync need explicit handling?
- Failure mid-take: the camera sleeps, overheats, or the USB drops (ticket 01 says how likely). Does the whole recording die, or does the screen keep recording with the circle frozen or gone? Which do you want?
- Ctrl-C handling: a single process gets SIGINT and must finalise a valid container. Several processes need coordinated shutdown.
- Where does the temp file live before the rename, and what guarantees it is a playable file if the machine dies?

Use `/grilling` and `/domain-modeling`.

**From ticket 01**: the camera stream is raw MJPEG with no container and no timestamps, and ffmpeg's raw demuxer fabricates 25 fps for it (`AVFMT_NOTIMESTAMPS`). Whatever shape is chosen has to deal with an input whose declared rate is a lie and whose real rate is unpaced ~10-25 fps.

**From ticket 05** (measured on the desktop, not guessed):

- **Every output needs its own stop condition.** With `-t` on the recording output only, ffmpeg
  ran on for minutes after the take finished, still serving the second output. Ctrl-C handling
  has to end all of them.
- **SIGKILL loses the whole take.** An mp4 killed mid-write has no moov atom and is
  unplayable — `moov atom not found` — even with 8 MB of video in it. Whatever guards against
  a crash mid-record, it is not mp4 as written here.
- `-thread_queue_size` must be raised on the rawvideo pipe input; the default 8 logs
  `Thread message queue blocking` immediately at 3440x1440@60. 512 was used throughout.
- Preview is settled as a **separate process** over a fifo-muxer pipe, so the supervisor
  question now includes at least one child (`ffplay`) beyond the encoder.

**From ticket 14**: the on-GPU composite is confirmed on the real hardware — `overlay_cuda`
blends the circle's alpha, nothing downloads, and `h264_nvenc` takes CUDA frames directly. The
filter graph this ticket has to shape is ticket 02's single-round-trip one, unchanged. The three
conditions are load-bearing: `format=yuva420p` before `hwupload_cuda` on the overlay,
`format=yuv420p` before it on the main input, and **no `-pix_fmt` on the NVENC output**.

**From ticket 12** (measured on the real camera, and it **supersedes the ticket 01 note above**):
the camera feed is *not* unpaced ~10–25 fps. It is camera-paced and rock steady — stills mode
960x640 @ **30.02 fps** fixed, movie mode 1024x576 @ exactly the Movie rec quality rate
(25.00P → 25.04, 50.00P → 50.10). Per-10s buckets over 70 s never left 24.9–25.1. So the
"declared rate is a lie" problem shrinks to *set the right constant*: ffmpeg's hardcoded
`framerate=25` matches FHD 25.00P by luck and is wrong for every other setting.

Two things this ticket now has to decide:

- **Which camera mode the pipeline assumes.** Movie @ FHD 50.00P (1024x576, 16:9, 50 fps) is
  the richest feed and crops to the circle with least waste, but movie mode is also the one
  ticket 13 is worried about thermally. Stills @ 30 fps is 960x640 3:2. Screen capture is
  60 fps either way, so the overlay input is always slower than the main input.
- **Guarding the geometry lock.** The camera emits 1–2 *stale-geometry* frames at the head of
  the first stream after any `liveviewsize` change or photo/movie switch, and ffmpeg's mjpeg
  demuxer locks to frame 0 unconditionally — `-probesize`/`-analyzeduration` do **not** help,
  verified. A take started right after touching the switch is silently encoded at the wrong
  geometry for its whole length. Fix by dropping leading frames, pinning `-f mjpeg
  -video_size`, or running a throwaway warm-up stream in preflight.

## Answer

Grilled on the real desktop (`s1n7ax`, ffmpeg **6.1.6**, GTX 1060). Four load-bearing facts were
measured here rather than assumed, and three of them overturn what the ticket body feared.

### Measured first

| claim | result |
|---|---|
| SIGINT to a multi-output ffmpeg | **finalises every output** — both files got full duration headers. Ticket 05's runaway was `-t` on one output only, not a Ctrl-C flaw. |
| mkv after SIGKILL | **survives** — 3439/3442 frames recovered, `File ended prematurely` warning only. |
| `overlay`/`overlay_cuda` on camera EOF | default is `eof_action=repeat`; **`pass` works on `overlay_cuda` on the 1060** — overlay region PSNR **3.9 dB** vs a no-overlay reference at t=1s (circle present), **36.9 dB** at t=6s after the camera died (indistinguishable from clean screen). The circle genuinely vanishes; nothing freezes. |
| preview-fifo handover between two writers | **broken, two independent ways.** The reader locks to the first stream's parameters and never re-reads the second nut header (`packet size 115200 < expected 230400`); and with byte-identical params, writer B's timestamps restart at 0 so **all 60 of its frames** are rejected as `non monotonically increasing dts`. |

### The shape

**One `ffmpeg` for the whole session, under a thin supervisor that only spawns and reaps.**

The handover result is what forces it. Since the preview window cannot survive a
preflight→take switch, there is no switch: the single ffmpeg starts at preflight and the file
rolls from the first preview frame. **Enter is a marker, not a switch** — the preflight head
gets trimmed in LosslessCut along with everything else, and the file is protected from second
zero rather than from Enter.

Order of operations:

1. **Warm-up, headless.** `gphoto2 --capture-movie` for ~2 s into a frame counter, discarded.
   No ffmpeg, no preview — ffmpeg must never see ticket 12's stale-geometry frames, and
   `-probesize` cannot save it if it does. The same burst measures geometry *and* rate.
2. **Preflight gate.** Refuse to start on any of three: geometry ≠ **1024x576**, measured rate
   outside **24.5–25.5**, or either ticket 11 audio node missing. Everything else warns and
   proceeds. The rate check is what catches "the menu was left on 50.00P". The geometry check
   also catches a wrong `liveviewsize` (which quarters the source to 512x288), so preflight
   never needs to *drive* the camera over PTP — checking is enough.
3. **Spawn**, in order: `ffplay` → `wf-recorder` → `gphoto2` → `ffmpeg`. The supervisor opens
   the preview fifo `O_RDWR` itself (`exec 3<>`, which never blocks — plain `3>` deadlocks
   waiting for a reader) so the open-ordering race between ffplay and ffmpeg cannot happen.
4. **Ctrl-C** → SIGINT **ffmpeg only** → wait 10 s → SIGTERM → wait 3 s → SIGKILL, then reap
   `gphoto2`, `wf-recorder`, `ffplay` unconditionally. **Close the holder fd before waiting on
   ffplay** — while it is open the reader can never see EOF and hangs. The SIGKILL rung is only
   acceptable because mkv survives it; ticket 05's `attempt_recovery` hang is what makes the
   timeout mandatory rather than optional.
5. **Rename**, then prompt.

### Camera mode: movie @ FHD 25.00P

Stills mode was the initial recommendation (exact 2:1 into 60 fps, more crop headroom, dodges
ticket 13's thermals) and was **rejected on a fact only the owner had**: *in stills mode the
camera powers off after a while*. So movie mode, 1024x576 @ 25.04 fps measured.

This makes **ticket 13 (camera power and thermals) load-bearing**, not optional — movie mode is
now the mode the pipeline is committed to.

### Output rate: 50 fps throughout

25.04 into 60 is 2.4:1 — each camera frame held 2 or 3 screen frames in a repeating 2,3,2,2,3
pattern, which reads as judder on a face. Into **50** it is exactly 2:1. 50 is a first-class
YouTube rate and NVENC has 2.3x headroom either way (ticket 14). The cost is screen capture at
50 instead of 60, which at 3440x1440 is marginal. *Resolves the map's 50-vs-60 fog.*

### Sync: wallclock on the pipes, never a declared rate

`-use_wallclock_as_timestamps 1` on **both** pipe inputs, `-fps_mode cfr` on the video output,
**no `-itsoffset`** until a measured offset actually appears.

This is not hygiene. The camera's real rate is 25.04, not 25.00. Declaring `-framerate 25` on
the mjpeg input drifts the circle **~3.8 seconds behind the audio over a 40-minute take** —
a lip-sync break, not a rounding error. Wallclock anchors all four inputs to one clock and lets
ffmpeg drop/dup onto the 50 fps grid.

### Camera dies mid-take: `eof_action=pass`

The circle disappears and the screen keeps recording clean. `repeat` (a frozen face) was the
initial recommendation on the grounds that it is a loud signal; rejected in favour of a file
that stays clean, since the preview already tells you the camera is gone.

### The file

Written **directly** into `/home/s1n7ax/Videos/Youtube/00 new/` as `<timestamp> UNTITLED.mkv`,
renamed in place on Ctrl-C after the description prompt. Same filesystem, so the rename is
atomic and no multi-GB copy happens; the timestamp is already unique. A crashed take therefore
leaves a **named, playable orphan** rather than something in `/tmp` that a reboot eats.

**Orphans get named on the next run.** The supervisor globs `* UNTITLED.mkv` at startup and
prompts for a description for each before starting the new take — no daemon, no second command,
and it asks you at the one moment you still remember what the take was.
*Resolves the map's crash/description-prompt fog.*

> The **container choice itself (mkv vs mp4) stays ticket 07's**. This ticket only establishes
> that the SIGKILL rung of the shutdown ladder depends on a crash-survivable container.

### Session boundary: one run, one take

Multi-take was considered and **deferred**, not designed. The camera can change mode between
takes and the warm-up is ~2 s, so the friction is small; supporting it turns the supervisor into
a state machine and reintroduces exactly the restart problem the single-ffmpeg shape avoids.
Ship one-take; revisit only if the friction is real in practice. *Moved to Out of scope.*

### Left to other tickets

- The **mic level meter** during preflight — ticket 15 (under-circle HUD).
- **Container and NVENC settings** — ticket 07.
- **Language and packaging** of the supervisor — ticket 10.
- **Movie-mode thermals and power** — ticket 13, now load-bearing.
