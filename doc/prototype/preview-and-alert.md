# The corner preview, the level meter and the pause alert

Prototype notes for [#135](https://github.com/s1n7ax/nixos/issues/135), under
the map [#121](https://github.com/s1n7ax/nixos/issues/121). Rig in
`.scratch/auto-record/prototypes/135-preview-alert/`, forked from #134's
`audio.py`. Nothing here ships.

Three tickets had circled the preview without building one. #123 picked the
mechanism, #126 picked the place, #130 said nothing. This one put the window on
the screen, and the window turned out to be the easy part: attaching *anything*
to the composite tee wedged the whole GL pipeline, and it took a morning of
bisecting to find out why.

## The short version

All four questions answer yes, and four new constraints came with them.

| | |
| --- | --- |
| GLMemory to the sink | yes - `video/x-raw(memory:GLMemory), RGBA, 440x248, 15/1, texture-target=2D` |
| composite with the preview attached | **60.05 fps** (1252 muxed frames over 20.85 s) |
| preview rate | **15.0 fps** exactly, dropped on the GL side |
| the black box in the file | **none** - the box lands at x 3000-3439, the crop keeps x 440-2999 |
| alert on screen after the valve closes | **17.9-18.4 ms**, about one frame |
| alert in the file | **0.00%** of alert-red in every frame, including the two either side of the seam |

## 1. The preview holds 60 fps, and #126's constraint is narrower than it reads

`gtk4paintablesink` negotiates `GLMemory` on a `gtk4-layer-shell` surface with
no help: GTK hands the sink a `GdkGLContext`, the sink offers it to the
pipeline as `gst.gl.GLDisplay`, and `glcolorscale` upstream renders straight
into it. The branch is

```
mix. ! tee name=t
t. ! queue max-size-buffers=2 leaky=downstream
   ! videorate drop-only=true max-rate=15
   ! glcolorconvert ! glcolorscale
   ! video/x-raw(memory:GLMemory),format=RGBA,width=440,height=248
   ! gtk4paintablesink
```

`videorate drop-only=true` works on GL buffers - it never maps them - so the
frames are thrown away before anything is scaled, which is what #126 asked for.

Measured over three 20 s runs against the real screen capture, same content,
same encoder:

| preview branch | composite | preview | process CPU (20 s) |
| --- | --- | --- | --- |
| none | 60.09 fps | - | 4.04 s |
| GLMemory to `gtk4paintablesink` | 60.05 fps | 15.0 fps | 5.81 s |
| `gldownload ! videoconvert ! videoscale` | 60.05 fps | 15.0 fps | 6.45 s |

So the GL path costs **1.8 s of CPU per 20 s** - about 9% of one core - and the
download path 2.4 s. Both hold 60 fps.

That last row matters, because #126's note reads as an absolute: *nothing
CPU-side may hang off the composite tee*. At 15 fps a full-size download plus a
CPU scale is affordable. What killed #126 was the `pngenc` on the end of it,
not the `gldownload`. **The GL path is still the one to ship** - it is cheaper,
and it keeps the headroom for a busier desktop - but the constraint should be
stated as what it is, or the next person will design around a wall that is not
there.

### Two things that have to be got right, or nothing runs at all

**The record branch must negotiate before the preview branch starts
streaming.** Start the pipeline with `valve drop=true` - which is what "the
take starts paused until preflight says every feed is live" means - and the
first resume wedges the entire GL pipeline. Not an error, not an EOS: buffer
counts freeze, `mux_pts` stays at zero, the main loop keeps running, and the
heartbeat prints the same numbers until it is killed. The last thing in the log
is always the same line:

```
queue1  got reconfigure event
tee     gst_tee_query_allocation:<t> Aggregating allocation from pad t:src_0
```

The encoder sees its first buffer, sends a `reconfigure` upstream, the `tee`
re-runs its allocation query across both branches, and the query never comes
back.

It reproduced every time and it is not any of the things it looks like. Ruled
out one at a time: leaky vs non-leaky queue, queue depth 2 or 3 or none at all,
which branch owns `src_0`, a GL filter on the preview branch vs a bare
`fakesink`, `videorate` present or absent, the centre crop, the Python pad
probes, `Gtk.init` - and the very same pipeline description, copied verbatim
out of the log into `gst-launch-1.0`, runs for 720 frames without a stumble,
because there the valve is open from the start. Answering the allocation query
at the tee pad with a probe made it worse, not better.

With the valves open at PLAYING, everything works: two scripted pauses and a
real mic death all closed and reopened the valve mid-take with the preview
attached, 6.0 s excised and the mux still at 60 fps. **The wedge is only ever
the first negotiation.** So the program has to let the record branch negotiate
while the pipeline comes up, and enter its paused state afterwards - or attach
the preview branch only once the first frame has been muxed.

**`glvideomixer` can emit two frames carrying the same PTS.** When a sink joins
the graph late the mixer repeats its first output, with double the duration:

```
vvalve out #1: pts=0         dur=16666666
vvalve out #2: pts=0         dur=33333333     <- same pts
vvalve out #3: pts=33333333  dur=16666667
```

The encoder then has two input frames for one timestamp and emits an output
buffer with no PTS at all, and `isofmp4mux` refuses it -

```
fmp4mux ... check_buffer:<mux:sink_0> Require timestamped buffers
```

\- which kills the take one frame in. It is not `qos`, `async`,
`processing-deadline` or `reconfigure-on-window-resize` on the sink; all four
were tried. A **monotonic-PTS guard** fixes it, and it belongs in the pad probe
in front of the encoder that #130 already put there for the pause excision:
drop any buffer whose PTS is not greater than the last one through. It fired
once per run against `videotestsrc` sources and never against the real screen
capture, so it is cheap insurance rather than a hot path.

## 2. The strip placement holds, in every layout

The layer surface asks for **352x249 logical**, the monitor is at scale 1.25,
and the compositor gives it **440x311 physical** anchored to the bottom-right
corner. The `no_screen_share` black rectangle in the captured frame is then

```
x 3000..3439   y 1129..1438      440 x 310 px
```

identical in all three layouts and while the alert is up - and the 2560 centre
crop keeps x 440..2999, so the box is outside it by exactly the margin #126
designed for.

The file says the same thing. Decoding the recording and counting pure-black
pixels across the whole 2560x1440 frame:

| layout | pure black | what it is |
| --- | --- | --- |
| 1, camera full-frame | 99.8% | the `videotestsrc ball` stand-in camera |
| 2, desktop + circle | 5.25% | 440x440 of stand-in camera, to the pixel |
| **3, desktop only** | **0.00%** | nothing |

Layout 3 is the proof: no camera on screen, and **not one pure-black pixel in
the frame**. #126's fallback - compositing over the hole - is not needed and
should not be built.

## 3. The meter, and a correction to #134

Three states, and they have to be different at a glance from a metre away:

- **live** - a filled bar, green to amber, with a peak-hold tick
- **silent** - an empty bar labelled `silent`, with the heartbeat pip still
  blinking: messages are arriving, the source is just quiet
- **dead** - a red bar with the word `DEAD`, and no pip

The numbers behind them are far apart, which is what makes the meter honest
rather than decorative: digital silence reads **-700 dB** rms (peak -350), room
tone through the fifine **-37 dB**, and a dead source stops producing `level`
messages at all - the rig calls it dead after 400 ms of no message. Screenshots
of all three are in `.scratch/auto-record/prototypes/135-preview-alert/out/`.

**#134's note and #134's rig disagree, and the rig is wrong.** The note says
the meter taps *before* the valves, and gives the reason: tapping ahead of them
keeps the meter alive while a take is paused, which is exactly when a feed
coming back needs watching. The rig's pipeline string puts `level` *after* the
valve on both audio sources. The consequence is visible the moment anything
pauses: **every bar reads DEAD**, including the feed that is still perfectly
alive and the one the user is standing there waiting for.

Moving the two `level` elements ahead of their valves fixes it, and the
screenshot of the same pause afterwards shows `MIC DEAD` next to a `DESK` bar
still bouncing. One element, one place, and without it the meter is worse than
nothing during a pause - it says the desktop died too.

## 4. The alert: 18 ms up, and never in the file

Measured on three runs, from `do_pause()` to the alert's own frame clock
reporting the frame painted:

| | |
| --- | --- |
| valve closed to alert painted | 18.4, 17.9, 18.0 ms |
| hide to the clean frame painted | 14.1, 14.9, 14.7 ms |
| hide to the valve reopening (`--alert-lead`) | 34 ms |

So the alert is up inside a 60 fps frame period, and the screen is clean for
about 19 ms before anything is recorded again.

The file agrees. The alert paints a colour nothing on a desktop is, and the
same detector run over a screenshot taken mid-pause finds **98.5% of the crop
region red**, so it is not blind. Run over the recording - sampling 2, 6, 10,
13, 14.5, 14.8, 14.85, 14.9, 14.95, 15.0, 15.2, 16 and 19 s, with the seam at
14.87 s - it finds **0.00% in every single frame**. The alert never reaches the
take, including the frames either side of the join.

Three things make that work:

- **The surface stays mapped for the whole take and paints nothing when idle.**
  Mapping and unmapping it per pause is a compositor roundtrip; a mapped
  surface that clears itself is one frame. It needs an empty input region
  (`Gdk.Surface.set_input_region`) or it eats every click for the whole take.
- **The alert goes on the TOP layer, not OVERLAY.** Two surfaces on the same
  layer stack in map order, so a full-screen OVERLAY alert buries the preview
  and the meter - precisely when #134 says the meter matters most. One layer
  down it still covers every window, and the preview still shows through. The
  screenshot of this is worth a look: the preview is mirroring the composite,
  the composite contains the screen capture, and the screen capture contains
  the alert, so the alert appears twice.
- **The hide leads the resume.** `--alert-lead 34 ms` is two frames and
  comfortably more than the 14-15 ms the paint actually takes. Nothing in the
  measurements argues for more.

## What it took to run at all: gtk4-layer-shell needs `LD_PRELOAD`

Every layer-shell call warned

```
Failed to initialize layer surface, GTK4 Layer Shell may have been linked
after libwayland. GtkWindow is not a layer surface.
```

and the preview came up as an ordinary toplevel. The library hooks
`wl_display_connect`, so it has to be loaded before `libwayland-client`, and
PyGObject dlopens the typelib long after python has already pulled wayland in.
`LD_PRELOAD=.../libgtk4-layer-shell.so` is the documented escape hatch and it
works. The repo's own `voice-indicator` has the same shape and presumably the
same latent bug; a Rust binary linking the library directly does not, as long
as the linker order is right, which is the whole reason the warning exists.

The other runtime nuisance: `hyprctl keyword layerrule` is refused outright
under a Lua config (`keyword can't work with non-legacy parsers. Use eval.`).
The rule has to go in through `hyprctl eval 'hl.layer_rule({...})'`, or - for
the real thing - into the config, which is a hand-off item.

## The one that is not #135's, and is worse than #135's

The rig carries #133's mic recovery and #134's audio mix at the same time, and
they are in direct conflict. Killing the mic node mid-take, with everything
else at its settled setting:

| | mixed track | raw mic track |
| --- | --- | --- |
| with `--drop-restart-events` (#133's fix) | **digital silence for ~4 s** after the swap | clean throughout |
| without it | clean throughout | **7 s of silence at the head**, content displaced |
| manual pause, no swap (control) | clean | clean |

In a longer run the mixed track never came back at all - silence for the
remaining 10 s of an 18 s take, while both raw tracks stayed at -37 and -29 dB.
The `level` tap on the mixer's output reads fine the whole time, so the mixer
is producing audio; it is the track that is empty.

#133 dropped the replacement source's `STREAM_START` and `SEGMENT` to close a
192 ms hole in the raw mic track, and that is the right fix for the raw track.
It is the wrong fix for the `audiomixer`, which needs the new segment to know
where the pad's time went. Neither ticket could have seen this, because neither
had both halves in one pipeline. It needs a step of its own; it is the mixed
track, the one the video actually carries.

## Reproducing

```bash
cd .scratch/auto-record/prototypes/135-preview-alert
hyprctl eval 'hl.layer_rule({ name = "wayfinder-preview-rule",
  match = { namespace = "^wayfinder-preview$" }, no_screen_share = true })'
nix-shell --run "python -u preview.py --system-clock --muxer isofmp4 \
  --frag 500 --iso-finalise --offset-mode rewrite --fake-camera \
  --mic-match fifine --desk-audio --meter 100 --preview gl --meter-widget \
  --alert --valve-open --layout 2 --record /tmp/x.mp4 --duration 26 \
  --report out/real.json"
```

Drop `--valve-open` to watch the tee wedge. `--preview-namespace
wayfinder-preview-shown` puts the preview outside the rule so `grim` can see
it. The rest of the flags, and what each one was for, are in the rig's
`README.md`.
