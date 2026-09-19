# PROTOTYPE — circle overlay (ticket 04)

Throwaway. Answers "how should the camera circle look and where does it sit" for
`.scratch/auto-record/issues/04-circle-overlay-prototype.md`. Nothing here ships.

`./render.sh` regenerates every variant from `screen.png` (mock 3440x1440 Hyprland screen,
rendered from HTML) and `cam.png` (stand-in 1024x576 camera frame — the R5's real geometry
comes from ticket 12). Both mocks are synthetic; no real capture was available on `dev-vm`.

Kept here: the four contact sheets the decision was made from, the chosen composite
(`FINAL-540-br-accent.jpg`) and the reusable mask (`circle-mask-540.png`). The intermediate
full-resolution variants were dropped — `render.sh` rebuilds them.

Verdict lives in the ticket's `## Answer`, not here.
