# PROTOTYPE - the corner preview, the level meter and the pause alert

Throwaway. Answers [#135](https://github.com/s1n7ax/nixos/issues/135) under the
map [#121](https://github.com/s1n7ax/nixos/issues/121). Forked from #134's
`audio.py`. Nothing here ships.

The verdict lives in the ticket and in `doc/prototype/preview-and-alert.md`.

## Running it

```bash
nix-shell --run 'python -u preview.py --help'
```

The money run - real screen capture, the preview in the strip, the meter, the
alert, and the three layouts:

```bash
nix-shell --run "python -u preview.py --system-clock --muxer isofmp4 \
  --frag 500 --iso-finalise --offset-mode rewrite --fake-camera \
  --mic-match fifine --desk-audio --meter 100 \
  --preview gl --meter-widget --alert --valve-open --layout 2 \
  --record /tmp/x.mp4 --duration 26 --report out/real.json \
  --script '3:grim=out/shot-l2.png,5:layout=1,7:grim=out/shot-l1.png,\
9:layout=3,11:grim=out/shot-l3.png,13:layout=2,15:pause,\
17:grim=out/shot-alert.png,20:resume'"
```

`--preview-namespace wayfinder-preview-shown` runs the same thing with a
namespace the Hyprland rule does *not* match, so `grim` shows the preview
instead of the black box. That is how the meter screenshots were taken.

The Hyprland rule this needs, added for the run and gone on the next reload
(`hyprctl keyword` is refused under a Lua config - it has to be `eval`):

```bash
hyprctl eval 'hl.layer_rule({ name = "wayfinder-preview-rule",
  match = { namespace = "^wayfinder-preview$" }, no_screen_share = true })'
```

## What this rig adds over #134's

| flag | why it exists |
| --- | --- |
| `--preview gl` | the real thing: `queue leaky ! videorate ! glcolorconvert ! glcolorscale ! gtk4paintablesink`, GLMemory all the way |
| `--preview direct` | no GL filter at all - the sink takes the composite's own 2560x1440 buffer and GTK scales the paintable |
| `--preview download` | the wrong way on purpose, so its cost can be quoted rather than assumed |
| `--preview bare` / `fakesink` / `custom` | controls. `--preview-sink` swaps in any sink, which is how `gtk4paintablesink` was separated from `glimagesink` and `fakevideosink` |
| `--meter-widget` | the two-bar meter under the picture |
| `--alert`, `--alert-mode`, `--alert-layer`, `--alert-lead` | the full-screen pause alert, mapped-for-the-take or presented per pause, on TOP or OVERLAY, and the ms between hiding it and reopening the valve |
| `--layout 1\|2\|3` + the `layout=N` script action | the three layouts, switched mid-take. #126 settled the look; this only needs them to point the camera somewhere different |
| `--no-crop` | what #134's rig did - *scale* 3440 into 2560 rather than crop it, which puts the strip back inside the frame |
| `--valve-open` | start recording immediately instead of starting paused. Not a preference: with the valves closed the `tee` wedges (see the doc) |
| `--monotonic` / `--no-monotonic` | drop a composite frame whose pts repeats the last one |
| `--preview-first`, `--preview-queue`, `--eat-alloc`, `--no-gtk`, `--no-probes`, `--probe-set`, `--no-window`, `--sink-props` | the bisect flags the tee deadlock was cornered with. Kept because they are the evidence |

New script actions: `layout=N`, `grim=<path>`, `geom`, `killmicnode`.

## Also here

- `out/` - the screenshots and reports the doc quotes.
- `micstart.sh` / `mickill.sh` / `deskstart.sh` / `deskkill.sh`,
  `audiocheck.py`, `seam.py` - unchanged from #134.

## Test rig, not a design

- **the camera is `videotestsrc pattern=ball`.** The R5 was not on the desk for
  this ticket and does not need to be: #126 settled the layouts against the
  real camera, and every question here is about the window, not the face. The
  ball is mostly black, which is why layout 2's frames read 5.25% pure black -
  that is the camera box, not a leaked preview.
- **the microphone is #134's null-sink stand-in** for the death tests and the
  real fifine for the first run. Both are in the reports.
- **`--screen-timeout 30000`** in the audio runs. The default 2s frame timeout
  false-fires on a static screen within seconds, which is #133's finding, and
  it would have paused most of those runs for the wrong reason.
