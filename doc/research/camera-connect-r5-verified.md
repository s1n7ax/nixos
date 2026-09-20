# camera-connect with the Canon R5 in movie mode: measured

Ticket: [#127](https://github.com/s1n7ax/nixos/issues/127). Map: [#121](https://github.com/s1n7ax/nixos/issues/121).
Supersedes the predictions in [#122](https://github.com/s1n7ax/nixos/issues/122) where they disagree.

Measured on this machine, 2026-09-20: Canon EOS R5 over USB in movie mode
(`/main/status/eosmovieswitch` = 1), kernel 6.18.50, v4l2loopback 0.15.3,
ffmpeg 8.1.2, libgphoto2 via `gphoto2`.

## The risk #122 raised does not reproduce

`gphoto2 --stdout --set-config viewfinder=1 --capture-movie` runs in movie mode
with no MIME abort and no hang. The TLV-type-9 / `GP_MIME_RAW` failure, and the
R5 C's reported hang on `--set-config viewfinder=1` in video mode, do not happen
on this body. The map's constraint that the camera is brought online by hand
before recording holds.

## Numbers

| | |
| --- | --- |
| Pixel format | MJPEG (`MJPG`), JPEG baseline, `yuvj422p` |
| Geometry | 1024x576, every frame, including the first |
| Real frame rate | 50.0 fps sustained |
| Frame size | ~102 KB, about 5.1 MB/s over USB |
| Advertised interval on the node | 30 fps, which is v4l2loopback's default and not the real rate |
| End-to-end latency | ~165 ms, glass to consumer |

Frame rate was measured four ways and agreed every time: 1499 frames in 29.96 s,
749 in 14.96 s, and three consecutive 20 s samples of 999 / 1000 / 999 frames
taken over a three-minute run. A separate 213 s continuous run delivered 10685
frames, 50.1 fps. The rate does not drift.

1024x576 is the confirmation that `viewfinder=1` takes effect. 512x288 would have
meant it silently failed.

Latency was measured by pointing the camera at a millisecond clock on the
monitor. The last frame of a capture burst read `19:29:22.628`; the capturing
process exited at `19:29:22.793`. That 165 ms covers camera liveview processing,
USB and PTP transfer, gphoto2, the ffmpeg stream copy, v4l2loopback, and the
consumer's own buffering. The camera feed is therefore about 165 ms behind the
microphone, and the recorder has to delay the audio to match.

## Failure modes

### A dead producer is indistinguishable from a quiet one

Unplugging the camera mid-stream killed gphoto2 (`ERROR: Movie capture error...
Exiting.`) and the loopback node dropped its capture capability, but the attached
consumer got no error and no EOF. `ffmpeg` sat in state `S (sleeping)` on
`/dev/video9` for four minutes after the producer was gone.

The map's "pause the recording if any feed dies" requirement cannot be built on a
read error. It needs a frame-arrival timeout; 200 ms is ten missed frames at
50 fps.

### Replugging does not bring the feed back

`19:31:18` USB gone, gphoto2 dead, capture capability lost. `19:31:36` USB back,
re-enumerated at a new address (`usb:001,009`). `/dev/video9` survived the whole
episode because the module stays loaded, so the path is stable, but nothing
streams to it again until `camera-connect` is re-run. Automatic resume means
re-running the producer, not waiting for the node.

### Only one consumer at a time

With `exclusive_caps=1`, a second process opening `/dev/video9` gets `Device or
resource busy`. The recorder and the corner preview cannot both open the camera
node. The program must read it once and tee internally.

### An unclean exit wedges the camera, and `gphoto2 --reset` unwedges it

After gphoto2 was killed abruptly, the camera still enumerated on USB and
`--auto-detect` still listed it, but every PTP command timed out (`PTP Timeout`,
`Timeout reading from or writing to the port`) and subsequent runs produced no
frames. `gphoto2 --reset` recovered it fully, with no replug and no power cycle.

A clean `SIGINT` does not wedge it: gphoto2 prints `Ctrl-C pressed ... Exiting.`
and the camera answers PTP normally afterwards. So stop the producer with
`SIGINT`, and call `gphoto2 --reset` on startup to clear whatever the last run
left behind.

## The script bugs

All three from #122 are real.

- `max_buffer=2` is real but benign. modprobe logs `v4l2loopback: unknown
  parameter 'max_buffer' ignored` and loads anyway, so the intended setting never
  applied. The correct name is `max_buffers` and its default is 2, so behaviour
  never actually differed.
- `ls -1 /sys/devices/virtual/video4linux` is real. Replaced: the module is loaded
  with `video_nr=9 card_label=camera`, so the path is a fixed `/dev/video9`, and
  the script checks `/sys/devices/virtual/video4linux/video9/name` before trusting
  it.
- `modprobe` being a no-op when already loaded is real and confirmed. Loading with
  `max_buffers=4 video_nr=7` while the module was already up returned exit 0 and
  changed nothing; `/dev/video7` never appeared. The script now unloads and
  reloads whenever the existing node's label is not `camera`.

A fourth bug, not in the ticket: the device node appears as `root:root 0600` and
only becomes group-`video` once udev catches up. The old script raced this. The
new one waits for `/dev/video9` to be writable, up to five seconds, and fails with
a clear message if it never is.

## Not settled here

- **Stills mode.** Not tested. The camera powers itself off after a while in
  stills mode, which rules it out as the recording path regardless; movie mode is
  the workflow.
- **Overheat.** Not measured. It shows up over a real long take rather than a
  short soak, and the program's response to it is the same pause-and-alert path as
  any other feed loss, which failure mode one already specifies.
