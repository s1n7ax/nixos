# What goes in the 381px HUD, and is it worth having

Type: grilling
Status: open

## Question

Ticket 05 proved a preview window parked inside the circle's inscribed square is invisible in
the recording — a private HUD on a single-monitor setup. It also fixed its ceiling: the circle
is 540px, so the HUD is **at most 381px**, and 340px was the size actually measured.

This ticket decides whether to build it, and what it shows.

- Is a 340px camera preview during the take actually useful, or is preflight-only enough? The
  camera is pointed at your face and does not move mid-take; the thing that can go wrong is the
  feed dying, which a still frame would not reveal.
- The map's fog listed a **recording-in-progress indicator** with no home. The HUD is a home
  for it. Does the take need one, given `record` is a foreground process in a terminal you can
  see?
- If the HUD exists, what shares those 340px — camera, mic meter, elapsed time, dropped-frame
  count? Ranked, because they compete for very little space.
- What draws it? `ffplay` shows one video stream and nothing else, so camera-plus-meter needs
  either a second ffmpeg compositing the HUD, or a small toolkit window. Cheapest thing that
  works.
- If the HUD is dropped entirely: what, if anything, tells you mid-take that the camera feed
  has stopped?

Use `/grilling` and `/domain-modeling`.

**From ticket 05**: placement is `hl.dsp.window.float/resize/move/pin` with `relative = false`,
logical coords (physical ÷ 1.25), window sized at birth via `ffplay -x/-y -noborder`. The
preview transport is settled — `-f fifo` with `drop_pkts_on_overflow`, never `attempt_recovery`.

**From ticket 06**: the **mic level meter** lands here. Ticket 06 settled that one ffmpeg spans
preflight and take with no handover, so there is no separate preflight UI to hang a meter on —
whatever meter exists must live in this HUD and run for the whole session. Note the HUD sits
inside the circle's 381px inscribed square (ticket 05) and the take is 50 fps (ticket 06).
