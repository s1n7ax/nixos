# PROTOTYPE — recovering the mic and the desktop mid-recording

Answers [#133](https://github.com/s1n7ax/nixos/issues/133) under the map
[#121](https://github.com/s1n7ax/nixos/issues/121). Rig:
`.scratch/auto-record/prototypes/133-feed-recovery/`, forked from #130's
`deadfeed.py`. Nothing here ships.

[#130](https://github.com/s1n7ax/nixos/issues/130) proved the pause and the
camera's resume and *diagnosed* the other two feeds without recovering either.
Both now recover on a running pipeline, the restore token survives a restart,
and the detector that #130 called an improvement turns out to be a correctness
fix rather than a latency one.

Measured on this machine: Hyprland 0.55.4, xdg-desktop-portal-hyprland 1.3.12,
PipeWire 1.6.6, a fifine USB microphone, GTX 1060, `nvh264enc` at 50 Mbps CBR
into `isofmp4mux fragment-duration=500ms`.

## The short version

| | detect | recover | dead time | seam in the file |
| --- | --- | --- | --- | --- |
| mic (stand-in null sink) | 16 ms | swap source 36–48 ms | 5.1 s (waiting for a human) | video 1 frame, audio **none** |
| mic (real fifine, via a wireplumber restart) | 22 ms | 1 failed try + 1 good, 53 ms | 2.18 s | video 1 frame, audio 37.6 ms |
| desktop | 10 ms | re-handshake 24–33 ms + swap branch 30–36 ms | 75–131 ms | video 1 frame, no audio effect |

Every file plays start to finish with no decode errors, and its duration equals
wall clock minus exactly the excised interval.

## Question 1 — rebuilding the audio branch

### Select the mic by serial, and by nothing else

#130 found `target-object=<node name>` silently ignored. It is worse than that.
Reading the PipeWire link graph while a `pipewiresrc` runs, rather than trusting
the property:

| `target-object` | what it actually connected to |
| --- | --- |
| `121` (the node's `object.serial`) | **proto133mic** — correct |
| `proto133mic` (its `node.name`) | the *default* source (the fifine) |
| `proto133mic.monitor` | the default source |
| `118` (its PipeWire **object id**) | the default source |

The id case is the trap. A serial and an id are both small integers, they sit
next to each other in `pw-dump`, and picking the wrong one produces a recorder
that runs perfectly and records the wrong microphone. Nothing warns.

Worse, neither identifier is stable. Across the runs here the stand-in mic came
back as **id 119 with serial 384** having died as **id 119 with serial 337** —
the id was recycled, the serial was not. The real fifine came back as id 91 and
then id 56 and then id 89, serial 61 → 1054 → 1158 → 1271. So the program must
key on `node.name` (stable, `alsa_input.usb-fifine_…`), resolve it to a serial,
and **re-resolve on every recovery**.

### The rebuild itself

`pipewiresrc` never reconnects, so recovery replaces it. Unlink its src pad from
the branch, `set_state(NULL)` (returns `success` in 1.4–2.7 ms), remove it, make
a fresh `pipewiresrc` with the newly-resolved serial, add, link to the same pad,
`sync_state_with_parent()`. 35–53 ms end to end, dominated by the `pw-dump` that
re-resolves the serial.

Everything downstream of the source — queue, valve, encoder, muxer pad — is
untouched, so the file keeps its audio track and the muxer keeps its pad.

### Drop the replacement source's `stream-start` and `segment`

The first working rebuild still left **192 ms missing from the audio track**,
and it stayed exactly 192 ms — nine AAC frames — however the rig was tuned:

- audio queue 200 ms / 50 ms / 20 ms → 192 ms every time, so it is not buffer
  depth;
- detection 223 ms (frame timeout) vs 16 ms (registry) → 192 ms either way, so
  it is not detection latency;
- the last mic buffer arrived **10 ms** before the node died, so the audio was
  not lost upstream;
- a manual pause of the same length with the mic **alive** the whole time left a
  32 ms hole, not 192 ms.

What is different in the death case is that a new element pushes a new
`STREAM_START` and `SEGMENT` down a branch that already has both. Dropping those
two events in a pad probe on the replacement source closes the hole completely:
audio gaps > 30 ms go to **none**, and every 250 ms window of the file is at
full level on the right tone.

This is only needed on the audio branch. The desktop branch is replaced whole
(below), so its new `glupload` wants the new segment, and the mixer resegments
anyway.

## Question 2 — bringing the desktop back

### Swap the whole GL head, not just the source

Replacing only the desktop's `pipewiresrc` fails. The re-handshake succeeds and
the swap completes, then the branch dies:

```
basetransform: second attempt to fixate caps returned invalid (NULL) caps
  on pad gluploadelement0:sink
ERROR from screen: Internal data stream error. … not-negotiated (-4)
```

A fresh portal stream arrives with its own DMABuf modifiers and the `glupload`
left over from the dead stream cannot renegotiate to them. The fix is to make
`pipewiresrc ! queue ! glupload ! glcolorconvert` one bin with a ghost src pad
and swap the whole bin, so the new stream negotiates from scratch. The mixer's
request pad — which carries the layout geometry the animation drives — is never
released, which is the property that matters.

Swapping the bin: 30–36 ms, `set_state(NULL)` 1.4–3.3 ms.

### The handshake

A fresh `CreateSession` → `SelectSources` → `Start` on top of the held session
takes **24–33 ms** with a cached restore token, matching #130's 34 ms. The new
node id and the new fd both have to go into the new source; both change every
time.

### Superseded sessions can be closed

#130 and #126 left every session open, so a long recording leaks one portal
session per recovery. Calling `org.freedesktop.portal.Session.Close` on the
*old* session after the new branch is already running takes **8 ms** and does
not disturb the live feed — proven across two consecutive recoveries in one run.
Close the old one; do not close the current one.

Hyprland 0.55.4 survived roughly fifteen handshakes across this session without
the `copyDmabuf` SIGSEGV #126 hit. That is not a licence to churn sessions, but
the recovery path's handful is evidently not what killed it.

### The restore token — and the trap in front of it

The round trip works and outlives the process. A token minted in one run
restored in two later, separate processes in **27–36 ms** with no picker, and
`Start` returns the **same** token string every time — it does not rotate, so
the program can write it once and leave it alone. #126's token, minted a day
earlier, still restored.

The trap is minting one at all. With `persist_mode=2` and no cached token, the
Hyprland picker appears and the portal logs `restore data invalid / missing,
prompting` — and then `Start` returns **no `restore_token`**, because
`hyprland-share-picker` has a checkbox, *"Allow a restore token"*, that is off by
default. Four separate first-run handshakes were answered at the picker and all
four came back tokenless. The failure is silent: the recording works, and every
future launch prompts again.

Two ways out, and the second is the one to ship:

1. The user ticks the box the first time.
2. `~/.config/hypr/xdph.conf`:

   ```
   screencopy {
       allow_token_by_default = true
   }
   ```

   With that in place the very next picker answer minted
   `54fffd1e-…` with no checkbox involved. **This file does not exist on this
   machine and is not in the repo** — it was written to test the option and
   removed again. It belongs in `system/nixos/utils/xdg.nix` or the
   home-manager Hyprland config before the recorder ships.

## Question 3 — detecting the desktop's death

Not a latency improvement. A correctness fix.

#130 measured a static screen as legitimately silent for 1.09 s and set the
watchdog at ~3 s. On a genuinely idle desktop that is nowhere near enough. In
these runs the desktop feed was legitimately silent for **7.9 s, 9.5 s** while
perfectly alive — and at a 3 s threshold the watchdog fired three times in 31 s
on a live feed, each false pause excising **377 ms of real content** from the
recording and burning a recovery attempt. There is no threshold that catches a
real death and not an idle screen, because the two are the same signal.

Watching the PipeWire registry for the node's removal ends the argument:

| | frame timeout | registry |
| --- | --- | --- |
| detect a real death | 3010 ms | **10 ms** |
| false positives on an idle desktop | 3 in 31 s | **0** |
| content lost to a false pause | 377 ms each | none |

The rig reads `pw-mon -N -o -a` and matches `removed:` against the watched node
id; the real program watches the registry through libpipewire directly. The
signal is the same.

The frame timeout stays, at a length that can only mean a feed is wedged rather
than idle — it is no longer the detector.

Two rules come with it:

- **A queued buffer is not the feed coming back.** A buffer arrived 9 ms after
  the node was destroyed and un-deadened the feed, so no recovery ran at all.
  The revive test has to be "data that arrived after the replacement source went
  in", not "data arrived".
- **A node in the registry is not yet connectable.** Recovering the real fifine
  the instant its node appeared failed with `stream error: target not found` —
  the swap raced wireplumber, which was still settling. The retry one second
  later worked. A failed swap must be a retry, never fatal.

## The mic has nothing to retry

The camera has `camera-connect` to re-run, three times, per
[#131](https://github.com/s1n7ax/nixos/issues/131). Nobody can restart a USB
microphone from software. So a missing mic node is not a failed attempt, it is a
wait: the program watches for a node matching `node.name` to appear and only
then attempts — and only then counts — a recovery. Retry budgets apply to the
swap racing the session manager, not to the mic's absence.

## Reproducing

```bash
cd .scratch/auto-record/prototypes/133-feed-recovery
nix-shell --run './micstart.sh'

# mic dies and comes back, everything on
nix-shell --run "python -u recover.py --fake-screen --fake-camera --system-clock \
  --mic-match proto133mic --offset-mode rewrite --muxer isofmp4 --frag 500 \
  --iso-finalise --registry-watch --auto-recover --audio-queue 20 \
  --drop-restart-events --record /tmp/x.mp4 \
  --script '8:sh=./mickill.sh,13:sh=./micstart.sh,22:stop'"

nix-shell --run 'python seam.py /tmp/x.mp4; python audiocheck.py /tmp/x.mp4'
```

Swap `--fake-screen` for the real desktop and add `20:killnode` to kill the
screencast node inside the held session. `--mic-match fifine` plus
`'8:sh=systemctl --user restart wireplumber'` is the real-microphone case.
