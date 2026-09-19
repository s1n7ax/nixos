# Confirm the real audio source names on the desktop

Type: task
Status: open

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
