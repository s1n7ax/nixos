# The circle: how it looks and where it sits

Type: prototype
Status: resolved

## Question

Build a throwaway ffmpeg filter chain against a still frame or short clip and look at it:

- Crop the camera feed to a square, then mask to a circle — `geq` alpha, an `alphamerge` with a generated circle PNG, or something cheaper.
- Size and corner on a 3440x1440 canvas: how big does the head need to be to read on a phone, and which corner stays clear of your usual window layout?
- Does the circle want a border or soft edge, and does that survive NVENC without ringing?
- Is the mask computed per frame (cost) or once (reused alpha)?

Use `/prototype`. Link the resulting filter string and a sample frame from this ticket.

**From ticket 02**: if the chain uses `overlay_cuda`, its main input must be **yuv420p**, not nv12, or the overlay carries no alpha — which is the whole circle.

## Answer

Prototyped with real ffmpeg composites against a mock 3440x1440 screen and a 1024x576
camera frame. Prototype captured on branch `prototype/04-circle-overlay` at
`.scratch/auto-record/prototypes/04-circle-overlay/` (`render.sh` regenerates every variant).

### Mask: computed once, never per frame

A static grayscale PNG fed through `alphamerge`, **not** `geq`. Benchmarked at 540px over
300 frames, 4 vCPUs, software only:

| approach | wall | per frame | max fps |
|---|---|---|---|
| `geq` alpha evaluated every frame | 9.50 s | 31.7 ms | ~31 |
| static mask PNG + `alphamerge` | 1.14 s | 3.8 ms | ~263 |

`geq` is **8.3x** more expensive and cannot hold 60 fps on CPU on its own. The mask depends
only on diameter and feather — both fixed constants — so it is generated once at script start
(or at Nix build time) and reused for the life of the take.

Generator:

```sh
ffmpeg -f lavfi -i "color=c=black:s=540x540,format=gray,\
geq=lum='clip((270-hypot(X-269.5,Y-269.5))*255/3,0,255)'" -frames:v 1 circle-mask-540.png
```

The `/3` is the feather width in pixels; the same expression gives a hard edge at `/1` and a
softer one at `/6`. Antialiasing is therefore free — it is baked into a PNG that is written once.

### Size: 540 px diameter

37% of frame height. Checked at phone scale by downscaling the full composite to a 390pt
portrait player and an 844pt landscape one:

- **300 px** — unreadable anywhere but a monitor.
- **420 px** — ~47pt on a portrait phone. Marginal.
- **540 px** — ~61pt portrait, ~132pt landscape. Reads. **Chosen.**
- **660 px** — best on a phone but swallows a large bite of whatever pane it covers.

21:9 is what forces the circle this large: a 3440-wide frame in a phone-width player is scaled
to roughly 11%, so anything under ~500px loses the face.

### Corner: bottom-right, 40 px margin

On a 3440x1440 canvas that is `overlay=2860:860`. Clears a top waybar and the bottom status bar.

### Edge: 3 px feather **and** a 6 px accent ring

The ring is load-bearing, not decoration. Tested against both backdrops:

- **No ring** — over a dark pane the circle boundary disappears entirely and you get a floating
  head with no edge. This is the failure case, and it is the common one on a dev screen.
- **White ring** — invisible over a light browser pane.
- **Near-black ring** (`#1e1e2e`) — invisible over a dark terminal pane.
- **Drop shadow** — reads on light, invisible on dark, and costs a second `overlay` pass.
- **Mid-tone accent ring** (`#89b4fa`) — the only treatment that holds a boundary over both.
  Costs one `pad` filter: the camera is scaled to 528x528 and padded to 540x540 in the ring
  colour before the mask is applied.

A 1 px feather still shows visible stair-stepping on the arc at 4x zoom; 3 px is smooth and,
being baked into the static mask, costs nothing at runtime.

### Filter string (software-validated)

```
[cam]crop=576:576:224:0,scale=528:528,pad=540:540:6:6:0x89b4fa,format=rgba[c];
[mask]format=gray[m];
[c][m]alphamerge[k];
[screen][k]overlay=2860:860
```

The crop `576:576:224:0` is a centred square on a 1024x576 source — the real numbers come from
the geometry ticket 12 measures. The crop is fixed and centred: framing is adjusted by moving
the camera, not in software.

### Fixed, not configurable

Size, corner, ring colour and feather are constants in the script. No flags, no Nix options —
the destination asks for one `record` command with nothing to configure by hand.

### Not settled here — needs the real GPU

Everything above was validated in **software** on `dev-vm`, which has no GPU. Whether
`overlay_cuda` on the GTX 1060 accepts an alpha-carrying overlay at all is untested, and the
ffmpeg 6.1 build here exposes no `format`/`alpha` option on the filter to inspect. If it cannot,
the composite falls back to a CPU `overlay` — measured at 18 ms/frame on 4 vCPUs for a 540px
circle onto 3440x1440, which is over the 16.7 ms budget at 60 fps here and only marginal on the
desktop. Split out as ticket 14.
