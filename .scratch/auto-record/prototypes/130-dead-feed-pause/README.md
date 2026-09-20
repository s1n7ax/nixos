# PROTOTYPE — the dead-feed pause path, and fragment duration vs the loss window

Throwaway. Answers [#130](https://github.com/s1n7ax/nixos/issues/130) under the
map [#121](https://github.com/s1n7ax/nixos/issues/121). Nothing here ships.

The verdict lives in the ticket and in `doc/prototype/dead-feed-pause.md`.

## Running it

```bash
nix-shell --run 'python -u deadfeed.py --help'
```

The rig builds the real 1440p60 composite — `glvideomixer` → `nvh264enc`
(50 Mbps CBR) → a fragmented MP4 — and drives scripted events at wall-clock
times so a measurement is reproducible without a keyboard.

```bash
# a 4 s manual pause, real desktop, real mic, synthetic camera
nix-shell --run 'python -u deadfeed.py --fake-camera --system-clock \
  --mic proto130mic.monitor --offset-mode rewrite \
  --record /tmp/x.mp4 --script "8:pause,12:resume,20:stop"'

# measure the file the way #124 did
nix-shell --run 'python seam.py /tmp/x.mp4'
```

`--fake-screen` and `--fake-camera` substitute `videotestsrc`, so geometry and
timing work needs nothing plugged in. A real desktop feed makes the ScreenCast
picker appear; the restore token is cached in `~/.cache/proto130-restore-token`
(seed it from `proto126-restore-token` to skip the dialog).

## Script events

`--script "<seconds>:<action>,..."`

| action | what it does |
| --- | --- |
| `pause` / `resume` | drive the valve by hand, ignoring the watchdog |
| `stop` | EOS and finalise |
| `killnode` | `pw-cli destroy` the screencast node — kills the desktop feed inside a held session |
| `killstream` | re-`CreateSession` with the same `session_handle_token`; also kills the feed but **wedges xdg-desktop-portal** (see below) |
| `killportal` | restart `xdg-desktop-portal-hyprland.service` |
| `killcam` / `startcam` | `SIGINT` gphoto2 / re-run `camera-connect` |
| `killmic` / `startmic` | unload / reload `module-null-sink` |
| `castalive` / `recast` | probe the held session; try a second handshake |
| `sh=<cmd>` | run any shell command — used to kill and restart `fakecam.sh` |

## Flags that matter

| flag | why it exists |
| --- | --- |
| `--system-clock` | pins `GstSystemClock`. Without it a `pipewiresrc` provides the pipeline clock and quantises the whole pipeline into ~0.5 s steps; a dead desktop feed then stops time altogether |
| `--offset-mode` | how the dead interval is excised: `rewrite` (PTS/DTS surgery in a pad probe), `valve-src` / `valve-sink` / `mux-sink` (`gst_pad_set_offset`), or `none` |
| `--muxer`, `--frag` | `hybrid` (`mp4mux fragment-mode=first-moov-then-finalise`), `dash` (plain `mp4mux` fragments) or `isofmp4` (`isofmp4mux`), at any fragment duration in ms |
| `--kill-after N` | `SIGKILL` itself after N s — the power-loss case |
| `--progress FILE` | unbuffered `write(2)` of the last PTS handed to the muxer, so the loss window has a ground truth that survives the kill |
| `--startcam-cmd` | what `startcam` runs. Default `camera-connect`; `./realcam.sh` for the real R5 without the `sudo modprobe` line, `./realcam-fast.sh` for the same with ffmpeg's probe short-circuited ([#131](https://github.com/s1n7ax/nixos/issues/131)) |
| `--startcam-log` | append that command's stderr to a file instead of discarding it — each line timestamped, which is how #131 split gphoto2's startup from ffmpeg's |

## Test rig, not a design

Three things here are deliberately crude and must not be copied into the real
program:

- **`fakecam.sh`** stands in for `camera-connect`: an ffmpeg producing 1024x576
  MJPEG at 50 fps into `/dev/video9`. #127 established that a dead V4L2 producer
  looks identical whatever the producer is, so killing this measures the same
  thing as killing gphoto2 — except for how long `camera-connect` takes to come
  back, which only the real R5 can say.
- **`killstream`** exploits a duplicate `session_handle_token`. It works, but it
  leaves `xdg-desktop-portal` stuck on *"Failed to close session
  implementation: Timeout was reached"* and every later `CreateSession` from any
  client times out. Recover with `systemctl --user restart
  xdg-desktop-portal-hyprland` **then** `xdg-desktop-portal`. Use `killnode`.
- **`realcam.sh` / `realcam-fast.sh`** are `camera-connect` with the `sudo
  modprobe` line removed, because sudo wants a password this rig cannot answer
  with its stdio closed. `realcamkill9.sh` SIGKILLs gphoto2 by exact process
  name for the unclean-stop case — never by `-f <pattern>`, which matches the
  test's own wrapper shell.
- **the mic** is a `module-null-sink` monitor, fed a sine by a separate
  `gst-launch` so it never suspends. An unfed monitor delivers one buffer every
  ~450 ms and makes the watchdog flap.
