# Preview that costs no frames

Type: prototype
Status: open

## Question

You want both a preflight preview (composited frame plus a mic level meter, Enter to start) and a preview that stays up during the take.

- How does the composited stream reach a preview window without re-capturing — `tee` muxer, `split` filter to an `sdl`/`ffplay` output, or a second consumer of the same source?
- Does the preview window itself get captured by the screen capture? If so, how is that avoided — a dedicated Hyprland workspace, a special window rule, or a second monitor-less output?
- What does the mic meter look like, given the recording holds the source? (`ebur128` filter's on-screen meter, or a separate `pactl` read.)
- Frame cost measured, not guessed: does preview during the take drop recording frames at 3440x1440?

Use `/prototype`. Link the working preview invocation from this ticket.
