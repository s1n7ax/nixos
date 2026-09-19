# One ffmpeg, or a supervisor over several?

Type: grilling
Status: open

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
