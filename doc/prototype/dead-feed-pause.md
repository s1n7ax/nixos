# The dead-feed pause path, and fragment duration vs the loss window

- Date: 2026-09-20
- Resolves: [#130](https://github.com/s1n7ax/nixos/issues/130) and
  [#131](https://github.com/s1n7ax/nixos/issues/131) — part of the
  Wayfinder map [#121](https://github.com/s1n7ax/nixos/issues/121)
- Questions: (1) does the `valve` + running-time-offset path actually pause and
  resume a recording when a feed *dies* rather than being politely stopped, per
  feed, with the seam measured the way [#124](https://github.com/s1n7ax/nixos/issues/124)
  measured it? (2) does a shorter `fragment-duration` close the loss window
  #124 saw, measured against the real 1440p60 composite rather than synthetic
  720p? (3) how long does `camera-connect` take to bring the real R5 back, which
  is how long a camera-loss pause actually lasts — added by
  [#131](https://github.com/s1n7ax/nixos/issues/131)?
- Rig: `.scratch/auto-record/prototypes/130-dead-feed-pause/` (throwaway)

## Answers in one paragraph each

**The dead-feed pause works, but not the way #124 proposed.** `valve drop=true`
is right; `gst_pad_set_offset()` is wrong — on three of the four placements
tried it has no effect at all, and on the fourth it destroys the content
recorded before the pause. Rewriting PTS/DTS in a buffer pad probe in front of
the encoder does work: an 11.7-second dead camera became a 45 ms bump, and a
4-second manual pause became a one-frame seam with audio and video durations
5 ms apart. Two things have to change besides the offset method. The pipeline
clock must be pinned to `GstSystemClock`, because letting a `pipewiresrc`
provide it makes a dead desktop feed stop time itself. And the three feeds die
and recover *differently* enough that one state machine cannot treat them
alike — the camera heals itself, the mic and the desktop never do.

**A shorter fragment duration does not close the loss window; the muxer choice
does.** At the real 50.5 Mbps, `mp4mux fragment-mode=first-moov-then-finalise`
lost the entire take in one run out of five, and shortening the fragment from
1000 ms to 100 ms did not help, because what decides recoverability is the atom
order, not the fragment size. `isofmp4mux` at 500 ms recovered every frame in
five of five, and `header-update-mode=rewrite write-mehd=true` gives it the
clean finalised file that was the hybrid muxer's only advantage — for +1.0% in
file size. **Swap the muxer.**

**A camera-loss pause lasts about one second, and half of that is fixable.**
With the real R5, `camera-connect` puts frames back on `/dev/video9` **730 ms**
after it is executed — but only 141 ms of that is gphoto2; the rest is ffmpeg
probing an MJPEG stream it is never told about. Told the format, the restart is
**174 ms** and the whole pause drops from 1.05 s to 0.50 s. Retries need no
delay between them. What no retry fixes is an unclean stop: `SIGKILL` wedges the
PTP session, `gphoto2 --reset` does not clear it and on the second try knocked
the camera off the USB bus altogether, and only the power switch brought it
back.

## Machine and pipeline under test

Same machine as #124 (Ryzen 9 5950X, GTX 1060 6GB, driver 580.173.02,
GStreamer 1.26.11, `gst-plugins-rs` 0.14.4, Hyprland 0.55.4,
xdg-desktop-portal 1.20.4, PipeWire 1.6.6).

```
pipewiresrc (portal screencast, one held session) ─┐
                                                   ├─ glupload ─ glvideomixer
v4l2src /dev/video9 (MJPEG 1024x576 @50) ──────────┘   2560x1440 @60, GLMemory
                                                            │
                                    queue ─ valve ─ queue ─ nvh264enc 50 Mbps cbr
                                              │                     │
pipewiresrc (mic) ─ queue ─ valve ─ audioconvert ─ avenc_aac ─── isofmp4mux ─ filesink
```

Measured output bitrate: 135 MB over 21.4 s = **50.5 Mbps**, so this is the real
rate the encode setting produces, which the 720p synthetic sources in #124 never
reached.

A pad probe on each mixer sink pad and on the audio valve's sink pad feeds a
50 ms watchdog. Each feed arms on its first buffer — nothing is recorded until
all three have delivered, which is the map's preflight requirement falling out
of the same mechanism. A feed goes dead when no buffer has arrived for its
threshold, and the recording resumes after 300 ms of continuous data from every
feed.

## Question 1 — the dead-feed pause

### The offset mechanism: four placements, one winner

Control: synthetic sources, 10 s run, a deliberate 2 s pause at 3 s, measured
with `ffprobe -show_entries frame=pts_time` and the largest interval between
consecutive frames — #124's method.

| how the dead interval is excised | frames | max inter-frame gap | verdict |
| --- | --- | --- | --- |
| nothing | 455 | **2.0167 s** | the hole is the pause |
| `gst_pad_set_offset()` on the **valve's sink** pad | 454 | **2.0167 s** | no effect whatsoever |
| `gst_pad_set_offset()` on the **muxer's sink** pad | 334 | **2.0167 s** | no effect whatsoever |
| `gst_pad_set_offset()` on the **valve's src** pad | 334 | 0.0167 s | seam clean, but the file's first PTS jumps to 1.98 s and everything recorded before the pause is gone |
| **rewrite PTS/DTS in a BUFFER pad probe on the valve's src pad** | 430 | **0.0167 s** | content intact, seam one frame period, no gap above 25 ms anywhere |

`gst_pad_set_offset()` only bites on a SEGMENT event that crosses that pad
*after* the offset is set. A reopening `valve` re-pushes its sticky events
through its **src** pad only, so that is the single placement where the offset
is ever applied — and when it is, `mp4mux` reads the shifted segment as a new
timeline and drops what it had already accumulated. The documented approach in
#124 was plausible and is not usable.

The probe is three lines: subtract the accumulated dead time from `pts` and
`dts`. Because it sits in front of the encoder, the encoder never sees a
timestamp discontinuity and no forced keyframe is needed. The same subtraction
on the audio branch, with the camera's ~165 ms lag folded in, keeps A/V aligned:
across a 4 s pause, video 15.9665 s against audio 15.976 s.

### Per feed

`isofmp4mux fragment-duration=500ms header-update-mode=rewrite write-mehd=true`,
PTS-rewrite offsets, `GstSystemClock` pinned.

#### Camera — `v4l2src` on `/dev/video9`

Producer killed with `SIGINT`, restarted 12 s later.

```
10.976  producer signalled
11.464  last frame arrives            (~0.49 s still buffered downstream)
11.693  DEAD: no data for 229 ms      -> valve closes, running time noted
22.976  producer restarted
23.048  first frame back              (72 ms later)
23.348  RESUME                        (after the 300 ms stability window)
```

File: 33.34 s, video 33.312 s against audio 33.317 s, **largest gap 0.045 s at
the seam** — three frame periods, not one, but 11.7 s of dead camera reduced to
45 ms. No decode errors.

The important part is the 72 ms: the **same `v4l2src` element, which never
closed the device, picked the new producer up by itself**. No reopen, no
dynamic relink, no state change. #127 established that only one process may
open the node; it does not follow that the reader has to let go when the writer
dies, and it does not.

Killing the producer with `SIGINT` leaves roughly half a second of frames still
in flight, so the last half-second before a camera death is real footage, not
frozen frames.

The producer here was an ffmpeg feeding `/dev/video9` the same 1024x576 MJPEG at
50 fps (`fakecam.sh`), because the R5 was not available that session. #127
established that a dead V4L2 producer is indistinguishable whatever the producer
was, so detection and the seam transfer directly; the `camera-connect` startup
latency does not, and **Question 3** below measures it against the real camera.

#### Mic — `pipewiresrc`

Target node destroyed, an identical node recreated 14 s later.

```
10.976  node destroyed
11.193  DEAD: no data for 204 ms      -> 217 ms after the last buffer
24.976  an identical node appears
        ... nothing. 234 buffers at death, 234 buffers at the end of the run.
```

No error, no EOS — buffers simply stop, exactly like the camera. But **the
element never reconnects.** Recreating the node does nothing; `pipewiresrc` is
finished. Recovering the mic means tearing the audio branch down and rebuilding
it (or cycling the element through NULL and re-targeting), which is a different
operation from anything the camera needs.

One harness trap worth recording because it is an implementation trap too:
`pipewiresrc target-object=<node name>` was **silently ignored** — the recorder
connected to the *default* source instead, which `pactl list source-outputs`
showed sitting on the USB mic while the test believed it was on the stand-in.
A first run that looks fine can be recording the wrong source. #124 already
noted that the portal docs recommend `pipewire-serial` / `PW_KEY_TARGET_OBJECT`
over node IDs; this says a node *name* is no better. Select by serial.

#### Desktop — `pipewiresrc` on the held portal session

The node destroyed with `pw-cli destroy`, which kills the feed while leaving the
session object intact — the shape #130 asked about.

```
43.758  first frame (the share picker took 43 s to be answered by hand)
63.633  node destroyed
66.611  DEAD: no data for 3035 ms     -> the timeout, nothing else
69.634  the portal session still answers as alive
75.633  a second handshake -> blocks on the share picker, never returns
```

What a dead desktop feed looks like from inside a held session:

- **No error and no EOS**, same as the other two.
- **No `org.freedesktop.portal.Session.Closed` signal.** The session object is
  still there and still answers. D-Bus tells you nothing.
- Frame arrival is the only available signal, and it is a blunt one. On a real,
  mostly-static desktop the feed delivered **238 frames in 20 s (~12 fps) with a
  worst-case silence of 1.09 s**. A 2 s threshold false-fired 3.2 s into another
  run; 3 s held. So the pause lands **~3 s after the feed actually died**, and
  those 3 s of frozen desktop are in the file.
- **It never comes back on the same element**, like the mic.

Recovery therefore means a fresh handshake, and that was measured twice with
opposite results. With a valid cached restore token, a second `CreateSession` →
`SelectSources` → `Start` on a live session completed in **34 ms** and returned
a new node id. Without one it opened the share picker and waited for a human —
which defeats the purpose of automatic resume. **The recorder must obtain and
persist a restore token** (`persist_mode=2`, store what `Start` returns) or
recovery is not automatic.

Restarting `xdg-desktop-portal-hyprland` was also tried: it kills the feed and,
like everything else, produces no signal on the client side.

### The clock is a trap, twice

Any `pipewiresrc` in the pipeline becomes the clock provider, and both feeds
that use one cause a distinct failure.

**The mic's `pipewiresrc` quantises the whole pipeline.** Identical 10 s runs,
the only difference being whether `GstSystemClock` was pinned:

| | mic buffers | max gap: screen / camera / mic | spurious dead events |
| --- | --- | --- | --- |
| `GstPipeWireClock` (default) | 64 | 0.456 / 0.466 / **0.476 s** | DEAD/BACK twice a second, the valve closed most of the run |
| **`GstSystemClock` pinned** | 464 | **0.017 / 0.022 / 0.022 s** | none |

Every feed's inter-buffer gap collapsed from ~0.47 s to one frame period. The
pipeline was advancing in the mic's ~0.5 s quantum.

**The desktop's `pipewiresrc` stops time when it dies.** With the default clock,
killing the desktop feed froze the pipeline's running time at 19.88 s for the
rest of the run, and camera and mic stalled within 240 ms — so all three feeds
looked dead at once and the pause arithmetic, which is `running_time_now -
running_time_at_pause`, had nothing to measure. Worse, EOS never reached the
sink and `set_state(NULL)` never returned; the process had to be `SIGKILL`ed.
With the clock pinned, the same kill paused cleanly and the other two feeds kept
running.

```c
gst_pipeline_use_clock (GST_PIPELINE (pipeline), gst_system_clock_obtain ());
```

## Question 2 — fragment duration vs the loss window

`SIGKILL` with no EOS, real 1440p60 composite at 50.5 Mbps. Ground truth is a
sidecar written with unbuffered `write(2)` recording the last PTS handed to the
muxer, so it survives the kill: 1290 video frames, last PTS 21.483 s.

Five samples each at `fragment-duration` 500 ms, killed at the same 22 s:

| | readable | frames recovered | loss window |
| --- | --- | --- | --- |
| `mp4mux fragment-duration=500 fragment-mode=first-moov-then-finalise` | **4 / 5** | 0, 1225, 1226, 1253, 1255 | **total loss**, 0.533, 0.533, 0.033, 0.017 s |
| `isofmp4mux fragment-duration=500ms` | **5 / 5** | 1288, 1290, 1290, 1290, 1290 | 0.033, 0.000, 0.000, 0.000, 0.500 s |

Shortening the fragment does not rescue the hybrid muxer. One sample at each of
1000 / 500 / 250 / 100 ms produced unreadable files at 1000, 500 and 100 ms and
a readable one at 250 ms — the duration is not what decides it.

What decides it is the atom order. `mp4mux` in `first-moov-then-finalise` mode
writes:

```
ftyp free mdat(5.6 MB) moov free mdat(5.6 MB) moof free mdat(5.9 MB) moof ...
```

The payload precedes both the `moov` and the `moof` that describes it. A kill
landing in the wrong place leaves a header ffmpeg refuses — "error reading
header", not "moov atom not found" — and `ffmpeg -i broken.mp4 -c copy` cannot
repair it either, which is the recovery #124 relied on. `isofmp4mux` writes the
textbook order and every fragment is self-describing:

```
ftyp moov(init) styp moof mdat styp moof mdat ...
```

135 MB of perfectly good video on disk and not one readable frame is the exact
failure the crash-safety requirement exists to prevent, and at 1440p60 the
hybrid muxer hits it about one time in five.

### The hybrid muxer's advantage is available without it

`header-update-mode=rewrite write-mehd=true` makes `isofmp4mux` rewrite its
header at EOS. A clean stop then produces a fully indexed file — 15.98 s
duration, 934 frames, largest gap one frame period across a 4 s pause, no decode
errors — and a `SIGKILL` on the same configuration still recovered with 0.5 s
lost. Both properties at once.

### Cost of a short fragment

A fragment boundary forces a keyframe, so fragment duration buys recoverability
with keyframe density. At 50 Mbps CBR the bitrate is pinned, so the cost is
quality-per-bit rather than size:

| fragment | keyframes in 21.9 s | file |
| --- | --- | --- |
| hybrid, `gop-size=120` only | 11 | 135.2 MB |
| isofmp4 1000 ms | 21 | 132.7 MB |
| **isofmp4 500 ms** | **43** | **136.5 MB (+1.0%)** |
| isofmp4 250 ms | 86 | 136.9 MB (+1.3%) |
| isofmp4 100 ms | 215 | 137.1 MB (+1.4%) |

500 ms is the knee: at 1000 ms one run lost 0.5 s and 30 frames, at 500 ms three
of five lost nothing at all, and below 500 ms the keyframe count doubles for no
measured gain.

**Replace `mp4mux fragment-duration=1000 fragment-mode=first-moov-then-finalise`
with `isofmp4mux fragment-duration=500ms header-update-mode=rewrite
write-mehd=true`.**

## Question 3 — how long `camera-connect` takes to bring the R5 back

Added 2026-09-20 with the camera actually plugged in, which is what
[#131](https://github.com/s1n7ax/nixos/issues/131) was opened for. Same rig and
the same flags; `startcam` runs `realcam.sh` — `camera-connect` minus its
`sudo modprobe` line — instead of `fakecam.sh`.

### 730 ms, and 570 ms of it is ffmpeg guessing the format

Five runs, `SIGINT` to gphoto2 and then `camera-connect` again. Detection is
`324 ms` in every single run; the restart is the interval from the `exec` to
the first frame reaching the pipeline.

| restart fired | detect | restart | excised pause |
| --- | --- | --- | --- |
| 10 s after death | 324 ms | 735 ms | (10.7 s, gap dominated) |
| 6 s after death | 324 ms | 727 ms | (6.7 s, gap dominated) |
| 6 s after death | 324 ms | 732 ms | (6.7 s, gap dominated) |
| 25 ms after DEAD | 326 ms | 726 ms | **1.050 s** |
| 25 ms after DEAD | 324 ms | 774 ms | **1.100 s** |
| 25 ms after DEAD | 325 ms | 725 ms | **1.050 s** |

`realcam.sh` timestamps both halves of the pipe, and the split is lopsided:

```
+0 ms    exec
+141 ms  gphoto2: "Capturing preview frames as movie to 'stdout'"
+707 ms  ffmpeg:  "Input #0, mjpeg, from 'fd:'"
+735 ms  first frame on /dev/video9
```

gphoto2 reopening the PTP session, setting `viewfinder=1` and streaming is
**141 ms** — the cheap part. The expensive part is ffmpeg probing a stream
whose format is already known: it logs `Format mjpeg detected only with low
score of 25, misdetection possible!` and spends ~570 ms making up its mind.

Telling it instead — `-f mjpeg -probesize 32 -analyzeduration 0 -fflags
nobuffer`, as `realcam-fast.sh` does — collapses the restart to **174 ms**,
twice, to the millisecond:

| variant | restart | excised pause | wall clock, death to resume | seam in the file |
| --- | --- | --- | --- | --- |
| `camera-connect` as installed | ~730 ms | 1.05–1.10 s | ~1.42 s | 49.7 ms |
| with the probe told | 174 ms | **0.500 s** | 824 ms | 66.7 ms |

Same 1024x576 MJPEG out either way, no decode errors in either file. So the
camera-loss pause is `324 ms detect + 730 ms restart + 300 ms stability` ≈
**1.05 s**, and roughly half of it is removable by fixing one ffmpeg
invocation. A cold start straight after the camera is powered on is **832 ms**,
close enough to the warm number that the PTP session is clearly not what costs.

### The retry needs no delay between attempts

Re-running `camera-connect` 25 ms after the watchdog declared the feed dead
worked exactly as well as running it 10 s later — gphoto2 has already let go of
the camera by then, because the frame-silence timeout is longer than the ~85 ms
gphoto2 takes to exit on `SIGINT`. #121's three retries can therefore be
back-to-back, ~730 ms apart (~175 ms tuned). What they cannot fix is below.

### An unclean stop costs a power cycle, and `gphoto2 --reset` makes it worse

[#127](https://github.com/s1n7ax/nixos/issues/127)'s note says `gphoto2 --reset`
clears a wedged PTP session. It does not:

```
SIGKILL to gphoto2
camera-connect  -> "Capturing preview frames", then PTP Timeout 4.6 s later, 0 frames
gphoto2 --reset -> returns in 490 ms
camera-connect  -> PTP Timeout again, 3.1 s in, 0 frames
gphoto2 --reset -> *** Error (-7: 'I/O problem') ***
                   ...and the R5 leaves the USB bus entirely
gphoto2 --auto-detect -> empty; no 04a9 device under /sys/bus/usb/devices
```

Two further reset-and-retry cycles found no camera at all. Switching the R5 off
and on brought it straight back, and a normal `camera-connect` then returned in
832 ms. So for #121: `SIGINT` is the only acceptable stop, the recorder must
never escalate to `SIGKILL` on a camera that will not die, and when the three
retries are spent the alert has to say *power-cycle the camera* — there is no
recovery the program can perform itself.

### `camera-connect` as installed cannot be re-run unattended

Its first line is `sudo modprobe v4l2loopback exclusive_caps=1 max_buffer=2`,
and sudo wants a password on this machine. A recorder re-running the installed
script with its stdio closed gets a silent hang, not a camera. `boot.nix` has
`boot.extraModulePackages`, which only makes the module *available*. Either add
`boot.kernelModules = [ "v4l2loopback" ]` with the options in
`boot.extraModprobeConfig`, or make the script skip the modprobe when the
loopback node already exists. The measurements above used `realcam.sh`, which
is the script with that line removed.

## What the pause/resume state machine has to do

```
        ┌──────────── every feed armed (first buffer seen) ────────────┐
        │                                                             v
   PREFLIGHT ──> RECORDING <──── 300 ms of data from all three ──── PAUSED
                     │                                                ^
                     └──── any feed silent past its threshold ────────┘
```

Common to all three feeds: a dead feed produces **no error and no EOS**, so the
only detector is buffer arrival; the `valve` in front of the encoder closes; and
the dead interval is excised by subtracting it from PTS/DTS in the pad probe.
The clock is `GstSystemClock`, never a `pipewiresrc`'s.

| | threshold | how it recovers | what the program must do |
| --- | --- | --- | --- |
| **camera** | 200 ms (10 frames at 50 fps) | by itself, 72 ms after a producer appears | nothing to the pipeline. Re-run `camera-connect` up to three times, then leave the alert up and wait for a human — `SIGINT` to stop gphoto2, `gphoto2 --reset` if the PTP session wedges |
| **mic** | 200 ms | never | rebuild the audio branch: the element is finished. Select the source by serial, not by node name |
| **desktop** | **3 s** — a static screen can be silent for 1.09 s | never | re-handshake the portal, which takes 34 ms **only if a restore token is held**; then swap `pipewiresrc`'s `fd` and `path` and restart that branch |

Two decisions from the ticket:

- **Camera recovery is three attempts, then ask.** The failure this protects
  against is a nudged USB cable, which a retry fixes in seconds; the limit stops
  the program looping against a camera that is switched off.
- **There is no give-up timer.** A recording stays paused until F10 is pressed.
  The file on disk is playable to within half a second at every instant, so
  waiting costs nothing and a timer would close a take behind the user's back.

Consequences worth stating plainly:

- A dead desktop feed puts **about 3 seconds of frozen desktop** into the file
  before the pause. Frame arrival cannot do better than that, because a static
  screen is legitimately silent for over a second. If those 3 s matter, the
  detector has to change: watching the PipeWire registry for the node's
  destruction is instant and unambiguous, and is the obvious next thing to try.
- The **preflight and the watchdog are the same mechanism** — a feed is armed by
  its first buffer, and recording does not start until all three are armed. The
  startup wait is not counted as an excised interval, so the file starts at zero.
- Everything above pauses **all** feeds together, video and audio, because the
  offsets have to stay equal or A/V drifts. There is no partial pause.

## Corrections to earlier tickets

- **#124's `valve` + `gst_pad_set_offset()` plan does not work.** The valve half
  is right. Use a PTS/DTS rewrite in a pad probe for the offset half.
- **#124's muxer choice is superseded.** The hybrid `mp4mux` mode was chosen for
  its clean finalised output on the strength of a 720p test; at the real 1440p60
  bitrate it loses the whole take about one run in five, and `isofmp4mux` with
  `header-update-mode=rewrite` finalises just as cleanly.
- **#127's `gphoto2 --reset` recovery does not work.** An unclean stop wedges
  the camera exactly as #127 said, but the reset does not clear it — twice — and
  the second reset dropped the R5 off the USB bus entirely. The camera has to be
  switched off and on by hand.
- **#124's measured 2 s pause with a one-frame seam was an orderly `PAUSED`
  transition and is not reachable for a dead feed** — a blocked live source
  makes the state change hang. The valve keeps the pipeline PLAYING instead, and
  the seam is one frame for a deliberate pause and three frame periods across a
  real feed death.

## Rig notes

The harness lives in `.scratch/auto-record/prototypes/130-dead-feed-pause/` and
its README documents the flags and the scripted events. Two traps cost real time
and are written down there so they are not paid twice:

- Re-running `CreateSession` with a **duplicate `session_handle_token`** does
  destroy the stream while keeping the session — useful — but it leaves
  `xdg-desktop-portal` stuck on *"Failed to close session implementation:
  Timeout was reached"*, after which **every** `CreateSession` from any client
  times out. Recovery is restarting `xdg-desktop-portal-hyprland` **and then**
  `xdg-desktop-portal`, in that order. Use `pw-cli destroy <node>` instead.
- `pkill -f <pattern>` inside a `nix-shell --run` kills the wrapper shell,
  because the pattern is on the wrapper's own command line. Kill by pid, or by
  exact process name (`pkill -x gphoto2`). This is easy to pay twice: passing
  the pattern in `--script` puts it on the command line of the shell running the
  test as well, which then kills itself mid-run.
- `realcam.sh` is `camera-connect` with the `sudo modprobe` line removed and
  both halves of the pipe stderr-timestamped; `realcam-fast.sh` is the same with
  ffmpeg's probe short-circuited. `--startcam-cmd` chooses which one `startcam`
  runs, and `--startcam-log` keeps its stderr instead of discarding it.
