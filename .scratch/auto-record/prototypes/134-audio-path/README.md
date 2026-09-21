# PROTOTYPE - the full audio path

Throwaway. Answers [#134](https://github.com/s1n7ax/nixos/issues/134) under the
map [#121](https://github.com/s1n7ax/nixos/issues/121). Forked from #133's
`recover.py`. Nothing here ships.

The verdict lives in the ticket and in `doc/prototype/audio-path.md`.

## Running it

```bash
nix-shell --run 'python -u audio.py --help'
```

A mixed mic+desktop track, both raw streams as extra tracks, three level taps,
on the same real composite as #130 and #133.

```bash
nix-shell --run './micstart.sh'     # stand-in mic: a null sink fed a 440Hz sine
nix-shell --run './deskstart.sh'    # stand-in desktop sink, fed a 660Hz sine

nix-shell --run "python -u audio.py --fake-screen --fake-camera --system-clock \
  --muxer isofmp4 --frag 500 --iso-finalise --offset-mode rewrite \
  --mic-match proto133mic --desk-audio --raw-tracks --meter 200 \
  --registry-watch --auto-recover --drop-restart-events \
  --record /tmp/x.mp4 --script '8:sh=./deskkill.sh,14:sh=./deskstart.sh,24:stop'"

nix-shell --run 'python audiocheck.py /tmp/x.wav --tone 440'
```

Two tones, not one: the mic stand-in is 440 Hz and the desktop stand-in 660 Hz,
so `audiocheck.py` can say which source landed on which track. "It recorded
fine" would not have caught the mixer writing 6.6 s of silence into the mixed
track while the raw tracks were clean.

## What this rig adds over #133's

| flag | why it exists |
| --- | --- |
| `--desk-audio` | a second `pipewiresrc` on a sink monitor, mixed with the mic |
| `--desk-match <substr>` | pin one sink instead of following the default. Kept to *demonstrate* pinning, not to recommend it - following the default is what survives a headset connecting |
| `--raw-tracks` | raw mic and raw desktop as extra tracks in the same file |
| `--raw-files` | the rejected alternative: separate wav files |
| `--meter <ms>`, `--meter-log` | `level` taps on both inputs and on the mix |
| `--mic-delay`, `--desk-delay`, `--screen-delay` | per-branch sync correction. The recorder ships with all three at zero; these are how the measurements in the doc were taken |
| `--delay-mode probe\|padoffset` | PTS rewrite before the valve (raw tracks move too) or an aggregator pad offset (mix only) |
| `--desk-timeout` | ms of no desktop-audio buffers before it counts as dead. Honest here, unlike the screen |

New script actions: `killdesk`, `startdesk`, `deskrecover`.

## Also here

- `flasher.py` - a fullscreen window that flashes white and clicks to the
  default sink on the same main-loop tick. Pointed at by the camera, it puts
  the same event in three places at once: the screen branch, the camera branch
  and the desktop-audio track.
- `syncread.py` - reads the offsets back out of a recording. Flash mode for
  camera-versus-screen, `--clap` mode for camera-versus-microphone, since no
  speaker on this machine can put a generated click in front of the fifine.
- `audiocheck.py`, `seam.py` - unchanged from #133.
- `micstart.sh` / `mickill.sh` / `deskstart.sh` / `deskkill.sh` - the two
  stand-in sinks. Unloading is **by module index**, not by name: this rig runs
  two null sinks and `unload-module module-null-sink` takes down both at once.

## Test rig, not a design

- **the desktop sink** is a null sink made default. The real WH-1000XM6 was
  measured too and behaves the same (42 ms worst gap against the null sink's
  72 ms), so the stand-in is not hiding anything.
- **the clap** is the only stimulus the camera and the microphone can both
  witness here. It is coarse - one camera frame is 20 ms - so the number comes
  from cross-correlating every clap at once rather than from pairing peaks.
