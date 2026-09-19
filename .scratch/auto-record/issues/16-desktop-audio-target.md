# What counts as "desktop audio", and what does preflight do when the default sink isn't it?

Type: grilling
Status: open

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
