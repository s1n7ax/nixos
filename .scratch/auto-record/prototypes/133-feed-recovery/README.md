# PROTOTYPE — recovering the mic and the desktop mid-recording

Throwaway. Answers [#133](https://github.com/s1n7ax/nixos/issues/133) under the
map [#121](https://github.com/s1n7ax/nixos/issues/121). Forked from #130's
`deadfeed.py`. Nothing here ships.

The verdict lives in the ticket and in `doc/prototype/feed-recovery.md`.

## Running it

```bash
nix-shell --run 'python -u recover.py --help'
```

Same rig as #130 — real 1440p60 composite, `glvideomixer` → `nvh264enc` →
`isofmp4mux` — with scripted events at wall-clock times, plus the recovery
paths #130 only diagnosed.

```bash
nix-shell --run './micstart.sh'          # stand-in mic: a null sink fed a sine

nix-shell --run "python -u recover.py --fake-screen --fake-camera --system-clock \
  --mic-match proto133mic --offset-mode rewrite --muxer isofmp4 --frag 500 \
  --iso-finalise --registry-watch --auto-recover --audio-queue 20 \
  --drop-restart-events --record /tmp/x.mp4 \
  --script '8:sh=./mickill.sh,13:sh=./micstart.sh,22:stop'"

nix-shell --run 'python seam.py /tmp/x.mp4; python audiocheck.py /tmp/x.mp4'
```

## What this rig adds over #130's

| flag | why it exists |
| --- | --- |
| `--mic-match <substr>` | resolve a mic by `node.name` to its **serial**, at build time and again on every recovery. `--mic` (a raw `target-object`) is kept only to demonstrate that a name silently records the wrong source |
| `--registry-watch` | detect death from PipeWire's registry (`pw-mon`) instead of waiting for frames to stop. Without it the desktop's detector cannot tell dead from idle |
| `--auto-recover` | the watchdog recovers a dead feed itself, rather than a scripted `micrecover` / `screenrecover` |
| `--drop-restart-events` | eat the replacement source's `stream-start` and `segment`. Closes a 192 ms hole in the audio track; see the doc |
| `--audio-queue <ms>` | audio buffered in front of the valve. Sweeping it is how the 192 ms hole was shown *not* to be buffer depth |
| `--close-old-session` | `Session.Close` the superseded portal session after a swap instead of holding it for the run's life |
| `--max-recast N` | cap on portal re-handshakes per run — #126 crashed Hyprland on its eighth fresh session |
| `--max-retries`, `--retry-interval` | recovery attempts per death, and the gap between them |
| `--token-cache`, `--no-token` | where the restore token is cached, and forcing the picker |

New script actions: `micrecover`, `screenrecover`, `pwlist`.

## Also here

- `tokentest.py` — one portal handshake per process, printing token in/out,
  whether it rotated, and how long the handshake took. The only way to prove a
  token outlives the *process* rather than the object.
- `audiocheck.py` — per-250 ms RMS and peak frequency of a file's audio track.
  The stand-in mic is a 440 Hz sine, so a window that is quiet or off-tone means
  the source connected somewhere it was not told to. "It recorded fine" would
  never have shown that.
- `seam.py` — unchanged from #130.
- `whichmic`-style link-graph reading is not scripted here; it was done by hand
  with `pw-dump` while a `pipewiresrc` ran, and the result is in the doc.

## Test rig, not a design

- **the mic** is a `module-null-sink` monitor fed a sine by a separate
  `gst-launch`, as in #130. `mickill.sh` unloads the sink **before** killing the
  feeder: the other order leaves the monitor alive but silent for ~190 ms, and
  that silence lands in the file as a hole the recorder never caused.
- **the real-microphone case** kills the fifine by restarting wireplumber, not
  by unplugging it. `pw-cli destroy` on an ALSA source node does *not* self-heal
  — the node stays gone until wireplumber restarts.
- **`pw-mon`** stands in for a libpipewire registry listener. Same signal, same
  latency, one subprocess instead of a binding this rig does not have.
