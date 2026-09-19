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
