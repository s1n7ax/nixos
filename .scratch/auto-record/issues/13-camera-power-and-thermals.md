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
