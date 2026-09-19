# What counts as "desktop audio", and what does preflight do when the default sink isn't it?

Type: grilling
Status: resolved

## Question

Ticket 03 planned to open desktop audio as the monitor of whatever is the default sink.
Ticket 11 measured the machine and found that default is not trustworthy:

- The headset is default only because WirePlumber *remembers* it. Nothing is configured.
- With the headset off, the default falls through to `alsa_output.pci-0000_05_00.1.pro-output-3.monitor`
  — a GPU HDMI output nothing plays to. The take records a silent desktop track and nothing errors.
- That fallback is also `s32le`, and its siblings are **8-channel**, where the headset monitor is
  `s16le 2ch`. The wrong default changes the track's shape, not just its contents.

So:

- Is "desktop audio" defined as *the headset's monitor, pinned* (`bluez_output.58_18_62_1F_32_D3.1.monitor`),
  or *whatever the default sink is at start time*, or *whatever sink actually has a stream on it*?
- Should the record command refuse to start when the resolved desktop source looks wrong —
  and what is the test? Non-bluez? Zero streams attached? A live RMS check over the first second,
  reusing ticket 05's meter?
- Should the pipeline instead *set* the default sink (or pin `default.configured.audio.sink` in
  this repo's WirePlumber config) so there is nothing to resolve at record time?
- If the headset drops mid-take, the monitor source disappears. Does the take die, or does the
  desktop track go silent and keep going? (Overlaps ticket 06's failure-mid-take question —
  settle the audio half here.)
- Same question for the mic's profile suffix: pinned to `.analog-stereo`, which a profile switch
  to `input:iec958-stereo` would break. Does preflight check the name exists, or just let ffmpeg fail?

Use `/grilling` and `/domain-modeling`.

## Answer

Decided on the recommendations, on the desktop, 2026-09-20.

### The measurement that reframed the ticket

The ticket assumed the two failure shapes were "silent wrong source at start" and "source vanishes
mid-take, take dies or goes silent". The second is wrong. Measured here with a throwaway null sink
destroyed underneath a live capture:

```
BEFORE destroy:  Source Output #299  Source: 292   (rectest2.monitor)
AFTER  destroy:  Source Output #299  Source: 124   (bluez_output.58_18_62_1F_32_D3.1.monitor)
```

ffmpeg ran the full 30 s at 1x speed, exited 0, wrote a full-length file, and logged **nothing**.
PipeWire's pulse layer *moves* an orphaned capture stream to another source rather than ending it.
Three attempts to forbid the move all failed — the stream stayed alive and was moved in every case:

```
PIPEWIRE_PROPS='{ node.dont-reconnect = true }'   -> ALIVE, moved
PIPEWIRE_PROPS='{ stream.dont-move = true }'      -> ALIVE, moved
PULSE_PROP='stream.dont-move=true'                -> ALIVE, moved
```

So **pinning a name buys nothing after the take has started**, and this applies to the mic exactly
as much as to the desktop monitor: unplug the fifine mid-take and track 1 silently becomes whatever
PipeWire picks next (the headset's HFP input, if a call is taken). There is no error to catch, no
EOF, no rate change — only the stream's `Source:` id changes.

### 1. What "desktop audio" is

**The monitor of whatever sink is default at preflight**, resolved once and printed — not a pinned
name, not "whichever sink has streams".

- Pinning `bluez_output.58_18_62_1F_32_D3.1.monitor` goes dead the day a different pair of
  headphones is used, and fails closed in the worst way: a name that no longer exists.
- A dedicated null sink that `record` creates and re-routes every app into is studio-grade routing
  that has to be unpicked after every take.
- "Whichever sink has streams" is wrong precisely at preflight, when nothing is playing yet.

Resolved with `pw-metadata -n default` (ticket 11's one-liner, no new dependency), so it is the same
string ffmpeg would resolve from `@DEFAULT_MONITOR@` — but resolved *by us*, so it can be shown and
tested before the take rolls.

### 2. The refusal test: an exact blocklist, plus showing the name

Preflight **refuses to start** if the resolved desktop source matches
`alsa_output.pci-0000_05_00.1.pro-output-*`. Those four GPU HDMI monitors are the *only* thing the
default can wrongly fall through to on this machine (ticket 11 measured the priority order), and
nothing ever plays to them — so this is an exact test, not a heuristic. It is also the test that
catches the 8-channel `s32le` shape change before it reaches the muxer.

Rejected as gates:

- **Zero streams attached** — a silent moment at preflight is normal, not an error.
- **A live RMS check over the first second**, reusing ticket 05's meter — same objection. Sitting in
  silence before hitting Enter is the common case.

Alongside the refusal, the preflight screen **displays the resolved desktop source name** next to the
mic level meter, so the human confirms it by eye in the same glance that confirms the mic is live.
That is the real safety net; the blocklist only catches the one failure that is mechanical.

### 3. WirePlumber: do not pin `default.configured.audio.sink`

Ruled out. With the headset off, a configured default that does not exist falls through to raw
priority anyway — straight back to the GPU monitors this ticket exists to avoid. It changes nothing
about the failure and adds a declarative knob that has to stay in sync with whatever headphones are
in use. The preflight check covers it. This also clears the corresponding line from the map's
**Not yet specified**.

### 4. Mid-take drop: warn loudly, never kill the take

A **watcher** alongside the supervisor from ticket 06 polls the ffmpeg stream's source id
(`pactl subscribe`, or `pw-mon` for a no-new-dependency route) and, when it changes, prints a loud,
wall-clock-timestamped warning to the terminal:

```
!! 00:14:22  desktop audio moved: bluez_output.58_18_62_1F_32_D3.1.monitor -> alsa_output.pci-...
```

The take keeps rolling. This follows ticket 06's `eof_action=pass` ruling that the take is precious:
killing forty minutes of screen capture over one audio track contradicts it, and the two untouched
tracks mean a bad desktop track is recoverable in the edit. The warning exists so you know *which
minute* went bad without listening back to the whole take.

The same watcher covers the mic stream; it is one loop over both source outputs.

### 5. Preflight checks the mic name exists

`pw-dump` is grepped for the exact pinned name
(`alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo`) and preflight refuses
with a named message if it is absent — the `input:iec958-stereo` profile switch ticket 11 flagged is
the live case. Letting ffmpeg fail instead is worse: the failure arrives after the camera has warmed
up and the screen grab has started, and reads as a generic pulse error rather than "your mic changed
profile".

### Vocabulary

- **desktop source** — the monitor source resolved at preflight from the default sink. Not a device,
  not a sink: the monitor node name handed to `-f pulse`.
- **mic source** — the fifine's node name, pinned as a constant in the script.
- **preflight** — everything before Enter: resolve, validate, show the meter. Ticket 06 established
  that this is not a separate ffmpeg — the file is already rolling.
- **the move** — PipeWire silently relinking a capture stream to a different source when its own
  disappears. The failure mode this ticket exists to handle.

Status: resolved
