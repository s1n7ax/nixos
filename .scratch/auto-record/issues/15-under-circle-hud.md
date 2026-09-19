# What goes in the 381px HUD, and is it worth having

Type: grilling
Status: resolved

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

## Answer

**The HUD is the preview window and nothing else.** Build it; put nothing in it.

The window is not really this ticket's to decide — ticket 06 committed to one ffmpeg spanning
the session with a preview fifo and an `ffplay` reading it, so the window exists either way.
What this ticket settles is what shares the 381 px, and the answer is: nothing does.

### What it shows: the composite, scaled

`scale=340:-2` off the `split`, so **340x142** — the screen's own 21:9 aspect at the HUD's width,
not the 340x340 square ticket 05 measured with. It comfortably clears the inscribed square in
both axes.

Showing the *composite* rather than the camera is what makes it worth having. The circle is in
it, so `eof_action=pass` removing the circle when the camera dies is visible at a glance — which
is precisely the failure the ticket worried a still frame would not reveal. A bare camera
preview would show the feed dying but not the thing the file actually gets.

### The mic meter: preflight only, in the terminal

Ticket 06 handed the meter here on the grounds that there is no separate preflight UI to hang it
on. There is one — the terminal, before Enter — and that is where it goes: a dB bar with the
resolved desktop source name beside it, running until Enter and then stopping.

Not in the HUD during the take, for two reasons. Drawing text into those 340 px needs either a
second compositing ffmpeg or a toolkit window, for a signal whose only available response is to
stop the take. And ticket 05's objection — that the terminal is on screen and therefore in the
recording — is about the *take*, not preflight: before Enter you are looking at the terminal
deliberately, and after it you have switched to whatever you are demonstrating.

### Recording-in-progress indicator: not needed, and already there

`record` is a foreground process in a terminal, and the pinned preview window is itself the
indicator — it is on screen for the whole session and invisible in the file. Adding a second one
would be a light that says what the window already says.

### Elapsed time and dropped frames: the terminal

ffmpeg's own stderr carries both, live, and the mid-take source-move warnings land in the same
place with a wall-clock stamp. None of it belongs in 340 px of pixels that are hidden from the
file but competing with a face.
