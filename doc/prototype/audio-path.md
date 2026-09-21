# The full audio path: desktop audio, the mix, and the raw streams

Prototype notes for [#134](https://github.com/s1n7ax/nixos/issues/134), under the
map [#121](https://github.com/s1n7ax/nixos/issues/121). Rig in
`.scratch/auto-record/prototypes/134-audio-path/`, forked from #133's
`recover.py`. Nothing here ships.

Every prototype before this one carried one audio stream. This one carries
three tracks off two sources, on the real 1440p60 composite with the real R5,
the real fifine and the real Hyprland screen capture.

## The graph

```
mic  --queue--level--valve--tee--\
                            |     audiomixer--level--valve--aac--> track 1  (mix)
desk --queue--level--valve--tee--/
                            |  \--queue--aac--> track 2  (raw mic)
                             \----queue--aac--> track 3  (raw desktop)
```

Four tracks in one `isofmp4mux`, one valve per source **and one after the
mixer** (see below), one `level` tap per input.

## Desktop audio is a tap on the default sink, and it must not be pinned

`pipewiresrc` with `stream-properties="props,stream.capture.sink=true"` and
**no `target-object` at all** captures whatever the default sink is playing,
and keeps following it. Switching the default sink twice mid-capture moved the
capture across both times with **no gap at all** - the worst inter-buffer gap
over the whole run stayed at 63.6 ms, the same as an undisturbed one.

That is the opposite of #133's rule for the mic, and deliberately so. For the
mic you want *that* microphone, so you pin its serial and re-resolve it. For
desktop audio you want *whatever the user is playing to*, which on this machine
is a WH-1000XM6 that comes and goes. Pinning it would mean recording silence
from a sink nobody is using the moment the headset connects.

The identifier trap from #133 is here too, with a different shape. Capturing
the monitor of one named sink:

| `target-object=` | result |
| --- | --- |
| the sink's `object.serial` | the monitor, correct |
| the sink's `node.name` | the monitor, correct |
| the sink's **object id** | **pure digital silence** |
| `<name>.monitor` (the PulseAudio spelling) | **pure digital silence** |

No error either way. Since the id and the serial are lookalike small integers
sitting next to each other in `pw-dump`, the same trap that recorded the wrong
microphone in #133 records *nothing* here.

## A sink monitor never goes quiet, so a frame timeout is honest for it

This was the hazard the ticket named - a silent desktop source stalling the
mixer - and it does not happen. A monitor emits digital silence forever.

| sink | state | buffers | worst gap |
| --- | --- | --- | --- |
| null sink, tone playing | running | 701 in 30 s | 72.1 ms |
| null sink, nothing playing | idle | 1405 in 40 s | 63.7 ms |
| the GPU HDMI sink, never used | suspended | 1163 in 30 s | 63.7 ms |
| the real WH-1000XM6 over A2DP | idle | 1170 in 25 s | **42.2 ms** |

3269 buffers over 100 s and nothing worse than 72 ms. Compare #133, where a
*live* desktop video feed was silent for 9.5 s and no threshold could separate
dead from idle. Desktop audio is the opposite: **a frame-arrival timeout is a
correct death detector**, with 250 ms already giving 3.5x headroom.

Two things follow that matter more than they look:

- **A suspended, inaudible sink still carries what apps play to it.** A tone
  played to the GPU HDMI sink - which has nothing plugged into it and never
  leaves `suspended` - came back off its monitor at -21 dB. The recording keeps
  the app's audio even when the user cannot hear it.
- **The only real death is no sink at all.** Unloading the last sink stopped
  the buffers dead, with no error and no EOS, and they never resumed. That is
  the case preflight has to catch and the pause has to cover.

Microphone bleeding back through the monitor, the other hazard the ticket
named, does not arise: the tap is upstream of the speaker path, and the user
listens on Bluetooth headphones anyway.

## `audiomixer` synthesises silence, and it wrecked the mixed track

The bug worth carrying forward. Valves on the two sources stop the inputs, but
they do not stop the mixer: `audiomixer` keeps emitting on the clock and fills
an absent pad with digital silence. Those silence buffers sail into the encoder
carrying timestamps inside the paused region, which `total_offset` has not
grown to cover yet - it only grows at resume.

Measured: a 6.6 s pause put **6.6 s of digital silence into the mixed track**,
while both raw tracks joined cleanly across the same pause. The video branch
never had this problem because its valve sits *downstream* of the compositor.

The fix is a third valve after the mixer, closed with the other two. With it,
a pause leaves the mixed track as clean as the raw ones.

## The raw streams go in the same file, and they survive a SIGKILL

Extra tracks in the one `isofmp4mux`, not separate files. SIGKILL at 12.0 s,
five times:

| run | video | mix | raw mic | raw desk |
| --- | --- | --- | --- | --- |
| 1 | 11.350 s | 11.343 | 11.349 | 11.346 |
| 2 | 11.867 | 11.849 | 11.848 | 11.862 |
| 3 | 11.867 | 11.862 | 11.861 | 11.852 |
| 4 | 11.850 | 11.841 | 11.839 | 11.831 |
| 5 | 11.850 | 11.833 | 11.832 | 11.841 |

5/5, all four tracks playable to within 0.13-0.65 s of the kill, and a full
decode of every track on runs 1 and 5 reported no errors. The raw tracks
inherit #130's crash safety for free; separate files would each need their own
muxer and their own crash-safety story to get the same thing.

Two AAC tracks at 192 kbps against ~50 Mbps of video is under 1% of the file.

## The meter reads the two inputs, not the mix

Three `level` taps were built - mic, desktop, mixed - and the mixed one is
redundant. Digital silence reads **-700 dB**, a value no real audio approaches,
so a silent desktop is unmistakable on its own tap; on the mix it is invisible
under the mic. A dead source is a different signal again: it stops producing
level messages altogether, which is the same thing the feed watchdog sees.

So [#135](https://github.com/s1n7ax/nixos/issues/135) draws **two meters, one
per input**, and the taps belong *before* the valves so the meter keeps reading
while a take is paused - that is exactly when you want to watch a feed come
back.

## Two corrections to #121

**`/dev/video9` is not a fixed path.** `camera-connect` produced
**`/dev/video0`** this session. The number is whatever v4l2loopback is given
when the module loads, so the program has to find the node by its label rather
than hard-code a number.

**The camera is not ~165 ms behind the microphone on the composite.** #127
measured 165 ms glass-to-consumer with a clock photograph and ffmpeg's own
buffering in the path. Branch against branch inside the real composite, with a
white flash arriving twice - once through the screen capture and once through
the lens pointed at the monitor - the camera runs **~83 ms behind the screen**
and **~25 ms behind the microphone**, the latter agreed by cross-correlating
ten claps. The dominant misalignment is screen-versus-everything, not
microphone-versus-face, which is the reverse of what #121's note assumes.

It does not matter, because the recorder applies no delay at all - see the
requirement. It matters only if a take ever looks wrong, and then the number to
reach for is a screen delay, not an audio one.
