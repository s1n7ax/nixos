# record

One command, one take. Captures the 3440x1440 screen, the Canon R5's live view over
USB, the mic and desktop audio; composites the camera as a circle in the bottom-right
corner; previews the whole thing in a window hidden *under* that circle; and writes one
NVENC-encoded mkv into `~/Videos/Youtube/00 new`, ready to trim in LosslessCut.

```sh
record          # preflight, then a take
record --check  # preflight only: is the camera, mic and desktop audio ready?
```

Nothing is configurable. Size, corner, ring colour, monitor, rates and the mic's node
name are constants in `config.py` — the point of the command is that there is nothing
to set up before a take.

## What a run does

1. **Names orphans.** Any `* UNTITLED.mkv` an earlier run left behind is offered for a
   description first, while you still remember what it was.
2. **Preflight.** Resolves desktop audio from the current default sink, refuses the GPU
   HDMI fallthrough, checks the mic is there under its pinned name, then runs a ~2 s
   headless live-view burst and refuses unless it measures 1024x576 at 24.5-25.5 fps.
3. **Spawns** `ffplay`, `wf-recorder`, `gphoto2` and one `ffmpeg`, and parks the preview
   window inside the circle.
4. **Waits for Enter**, showing a mic level bar and the resolved desktop source. The
   file is already rolling — Enter is a marker to trim to, not a switch.
5. **Records** until Ctrl-C, shouting if PipeWire moves either capture to a different
   source, then walks ffmpeg down SIGINT → SIGTERM → SIGKILL and asks what the take was.

## Camera

Put the mode switch on **Movie**, Movie rec quality on **FHD 25.00P**, and
`liveviewsize` on **Large**. Preflight refuses anything else with a named message,
because the alternatives fail silently: stills mode is 960x640 and powers the body off,
`Medium`/`Small` quarter the source to 512x288, and a rate of 50 encodes a circle that
drifts out of sync. The feed carries no AF boxes or info overlay — there is nothing to
turn off.

## Why it is shaped this way

Every number here was measured on this machine, and the reasoning lives in
`.scratch/auto-record/`. The load-bearing ones:

- **One ffmpeg spans the whole session.** The preview fifo cannot survive a handover —
  the reader locks to the first stream's parameters and a second writer's timestamps
  restart at zero — so there is no handover.
- **`h264_nvenc`, not HEVC.** Pascal's HEVC encoder is ~30% less efficient here and
  hard-fails on `-bf 3`, so the old OBS `jim_hevc_nvenc` profile was wrong on this GPU.
- **mkv, not mp4.** The shutdown ladder ends in SIGKILL, which mkv survives (3439 of
  3442 frames recovered) and mp4 does not.
- **Three audio tracks.** A plain YouTube upload reads one and LosslessCut cannot mix,
  so track 0 is the mix and tracks 1 and 2 are the untouched pair.
- **The preview hides under the circle.** `wf-recorder` grabs the monitor's composited
  image, so anything visible is in the take — except what the overlay paints over.
- **Pinned names protect only the start of a take.** PipeWire *moves* an orphaned
  capture to another source rather than ending it, silently and with no EOF, so the
  watcher shouts and the take keeps rolling.

## Tests

Everything but the process glue in `main.py` is covered headlessly.

```sh
python3 -m unittest discover --pattern 'test_*.py'
```
