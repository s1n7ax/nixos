# Confirm the real audio source names on the desktop

Type: task
Status: resolved

## Question

Ticket 03 derived PipeWire's source-naming rules from the code that generates them, but ran on `dev-vm` where no PipeWire socket exists. The concrete names this machine will actually use are still unknown.

On the desktop machine, capture and record here:

- `pactl list short sources` — the full list, including monitors.
- `pactl get-default-sink` and `pactl get-default-source`.
- `wpctl status`.
- The exact node name of the mic that will be used for recording, so it can be pinned (ticket 03: binding to `default` lets a mid-take headset silently take over).
- Whether any name carries a `.2`…`.99` dedup counter, which would mean it is not stable.

Resolved when the two names — mic and desktop monitor — are written down verbatim in the answer, ready to drop into the pipeline.

## Note from ticket 05 (partial — capture the full listings here when resolving)

Read off the desktop while prototyping ticket 05:

- **`pactl` is not installed.** It is not in the system profile or the user profile; only
  `wpctl` and `pw-cli` are. Everything in ticket 03 assumes `pactl`, so either the record
  script pulls `pulseaudio` into its own PATH or the naming has to come from `wpctl`.
  This matters for ticket 10 (packaging).
- Mic, stable-looking, no dedup counter:
  `alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo`
- `pactl get-default-sink` → **`bluez_output.58_18_62_1F_32_D3.1`** — a Bluetooth headset.
  So `@DEFAULT_MONITOR@` today records the *headset's* monitor, not the desktop output. This
  is exactly the silent-wrong-source failure ticket 03 warned about, already live.
- The four `alsa_output.pci-0000_05_00.1.pro-output-*.monitor` sources are the GPU's HDMI/DP
  audio in pro-audio profile; none is the obvious "desktop audio" choice.

Concurrent access is confirmed working: a 6.07 s capture and a live level meter read the same
Fifine source simultaneously (ticket 05's `meter.sh`).

## Answer

Captured on the desktop (`s1n7ax`), PipeWire 1.6.6 / WirePlumber 1.6.6, 2026-09-19.

### The two names, verbatim

```
mic      alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo
desktop  bluez_output.58_18_62_1F_32_D3.1.monitor
```

Both were proved end to end, not just read off a listing — `ffmpeg -f pulse -i <name> -t 1 -f null -`
succeeded on each, and on `@DEFAULT_SOURCE@` / `@DEFAULT_MONITOR@` as well.

### `pactl list short sources` (the full listing)

`pactl` is still not installed (ticket 05 was right); this came from
`nix shell nixpkgs#pulseaudio -c pactl list short sources`:

```
57   alsa_output.pci-0000_05_00.1.pro-output-3.monitor                            PipeWire  s32le 2ch 48000Hz  SUSPENDED
58   alsa_output.pci-0000_05_00.1.pro-output-7.monitor                            PipeWire  s32le 8ch 48000Hz  SUSPENDED
59   alsa_output.pci-0000_05_00.1.pro-output-8.monitor                            PipeWire  s32le 8ch 48000Hz  SUSPENDED
60   alsa_output.pci-0000_05_00.1.pro-output-9.monitor                            PipeWire  s32le 8ch 48000Hz  SUSPENDED
61   alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo  PipeWire  s16le 2ch 48000Hz  SUSPENDED
124  bluez_output.58_18_62_1F_32_D3.1.monitor                                     PipeWire  s16le 2ch 48000Hz  SUSPENDED
```

`pactl get-default-sink` → `bluez_output.58_18_62_1F_32_D3.1`
`pactl get-default-source` → `alsa_input.usb-fifine_Microphones_fifine_Microphone_REV1.0-00.analog-stereo`

### `wpctl status`, trimmed to the audio tree

```
Devices:  48. GP106 High Definition Audio Controller [alsa]   (profile pro-audio)
          49. fifine  Microphone                     [alsa]   (profile input:analog-stereo)
          50. Starship/Matisse HD Audio Controller   [alsa]   (profile off)
         116. WH-1000XM6                             [bluez5] (profile a2dp-sink, codec AAC)
Sinks:    57/58/59/60. GP106 … Pro, Pro 7, Pro 8, Pro 9
       *  117. WH-1000XM6
Sources:  *  46. fifine  Microphone Analog Stereo
```

`wpctl` does **not** list monitor sources at all — only `pactl` or `pw-dump` shows them. Anything
the preflight prints about desktop audio has to come from `pw-dump`/`pw-metadata`, not `wpctl`.

### Dedup counters: none

No name carries a `.2`…`.99` dedup counter. The one numeric suffix, the `.1` on
`bluez_output.58_18_62_1F_32_D3.1`, is **not** a counter — it is `card.profile.device`, and
every profile the headset offers (`a2dp-sink-sbc`, `a2dp-sink`, `headset-head-unit`) maps its
sink to device index `1`. So the name survives an AAC↔SBC↔HFP switch unchanged.

### What is actually load-bearing

- **`pactl` is not needed by the pipeline at all.** ffmpeg resolves `@DEFAULT_MONITOR@` server-side
  itself (ticket 03), and for preflight to *display* the device,
  `pw-metadata -n default` + `jq` gives the same string with no new dependency — `pw-metadata` is
  already in `/run/current-system/sw/bin`. This closes ticket 05's packaging worry for ticket 10:
  no `pulseaudio` in the script's PATH.
  ```
  pw-metadata -n default | sed -n "s/.*key:'default.audio.sink' value:'\(.*\)' type.*/\1/p" | jq -r .name
  ```
- **The mic name is port-independent.** It derives from `device.serial`
  (`fifine_Microphones_fifine_Microphone_REV1.0`), not from `device.bus-path`
  (`pci-0000:07:00.3-usb-0:1.2:1.0`), so replugging into a different USB port keeps the name.
  A *second* identical fifine would collide and earn a dedup counter; there is one.
- **The mic's profile suffix is a live trap.** The card sits in `input:analog-stereo`, but also
  offers `input:iec958-stereo` — switching it renames the node to
  `…-00.iec958-stereo` and the pinned name goes dead. Ticket 03's profile-suffix warning is real
  on this hardware, not hypothetical.
- **`@DEFAULT_MONITOR@` is unsafe here, and worse than ticket 03 assumed.** The headset is default
  only because WirePlumber's `~/.local/state/wireplumber/default-nodes` remembers it:
  ```
  default.configured.audio.sink=
  default.configured.audio.sink.0=bluez_output.58_18_62_1F_32_D3.1
  default.configured.audio.sink.1=alsa_output.pci-0000_07_00.4.iec958-stereo
  ```
  Nothing is *configured* (the first line is empty) — it is a remembered-selection stack, and the
  `.1` fallback (onboard S/PDIF) no longer exists, since the Starship controller is `off` with
  `off` as its only available profile. With the headset disconnected the default therefore falls
  through to raw priority, which ranks the four GPU HDMI monitors (1196/1132/1116/1100)
  **above** the headset (1010). So a take started with the headset off silently records
  `alsa_output.pci-0000_05_00.1.pro-output-3.monitor` — a display-audio output nothing plays to.
- **That fallback also changes the track's shape**, not just its contents: the headset monitor is
  `s16le 2ch`, the GPU pro monitors are `s32le` and three of them are **8ch**. A silently-wrong
  default would hand the pipeline an 8-channel desktop track.
- **Headset HFP steals the mic too.** `headset-head-unit` exposes an `Audio/Source` at device 0
  (`bluez_input.58_18_62_1F_32_D3.0`); taking a call mid-take flips `default.audio.source` to it.
  Pinning the fifine name, as ticket 03 decided, is what prevents this.

### Concurrent access

Re-confirmed from ticket 05: a capture and a live level meter read the same fifine source
simultaneously with no error.

Status: resolved
