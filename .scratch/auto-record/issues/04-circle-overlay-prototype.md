# The circle: how it looks and where it sits

Type: prototype
Status: open

## Question

Build a throwaway ffmpeg filter chain against a still frame or short clip and look at it:

- Crop the camera feed to a square, then mask to a circle — `geq` alpha, an `alphamerge` with a generated circle PNG, or something cheaper.
- Size and corner on a 3440x1440 canvas: how big does the head need to be to read on a phone, and which corner stays clear of your usual window layout?
- Does the circle want a border or soft edge, and does that survive NVENC without ringing?
- Is the mask computed per frame (cost) or once (reused alpha)?

Use `/prototype`. Link the resulting filter string and a sample frame from this ticket.

**From ticket 02**: if the chain uses `overlay_cuda`, its main input must be **yuv420p**, not nv12, or the overlay carries no alpha — which is the whole circle.
