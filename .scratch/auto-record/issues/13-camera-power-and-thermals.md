# Camera settings and power for long takes

Type: task
Status: open

## Question

Ticket 01 found that extended Live View is itself what drives the R5's thermal auto-shutdown, and that USB-C cannot power the body.

Settle and apply:

- Camera menu: `Auto pwr off temp.` to High, `Standby: Low res.` to On, and no card inserted. Confirm each exists on the installed firmware and record where.
- Power: mains via AC-E6N + DR-E6 dummy battery, or accept battery life. If mains, the hardware has to be bought — say so plainly rather than assuming it is on hand.
- `KeepDeviceOn`: gphoto2 defeats the camera's auto-power-off with it, after which the R5 ignores its own power-saving menu and draws about 10 W. Decide whether the script sets it, and what turns it back off after a take.
- How long a take actually survives before thermal shutdown, measured once with the settings above.

Resolved when the settings are applied and the real sustainable take length is written down.

**From ticket 12**: `output=PC` — the setting that would blank the LCD to cut heat — **does not
stick**; the R5 reports `TFT + PC` straight back. The panel cannot be turned off over PTP, so
LCD heat is not a lever this script has. Also relevant to take length: live view is a genuine
25/30/50 fps readout (not a slow poll), and at FHD 50.00P it pushes **42.7 Mbit/s** over USB
continuously — so the 50p option this ticket's thermal test should use is the hot one.

**From ticket 06**: this ticket is now **load-bearing, not optional**. Stills mode was rejected
because the body powers itself off after a while, so the pipeline is committed to **movie mode @
FHD 25.00P** — the mode this ticket is worried about. Note the failure is no longer fatal to a
take: ticket 06 settled `eof_action=pass`, so a camera that dies mid-take removes the circle and
the screen keeps recording cleanly.
