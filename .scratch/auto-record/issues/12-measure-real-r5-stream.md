# Measure the R5's actual live-view stream

Type: task
Status: open

## Question

Ticket 01 established what `gphoto2 --capture-movie` *is* — polled PTP live view, concatenated baseline JPEGs — but no primary source states the R5's exact geometry and frame rate. The findings file gives two verification commands.

On the desktop, with the R5 connected:

- Actual pixel dimensions of the live-view frames, in movie mode and in stills mode (they differ).
- Actual sustained frame rate, measured over a minute or more rather than a burst.
- Whether the frames are baseline JPEG as expected, and their size.
- Whether the feed is clean — no focus box, no info overlay — and which menu setting controls that.

These numbers set the source resolution for the circle crop (ticket 04) and the output frame rate (ticket 07). Record them verbatim in the answer.
