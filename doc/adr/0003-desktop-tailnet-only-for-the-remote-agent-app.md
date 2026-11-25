# 3. The desktop reaches the tailnet only through the remote-agent app

- Status: Accepted
- Date: 2026-11-25
- Related: ticket 1 (remote-agent app and a top bar on the desktop)

## Context

The server joins the tailnet the usual way (`features.network.tailscale`):
a `tailscale0` interface, tailnet routes and MagicDNS for the whole machine,
with every tailnet device trusted like the LAN. The desktop needs the tailnet
for one thing only, the remote-agent board, and the user does not want
Tailscale to apply to the rest of the system.

## Decision

The desktop does not enable `features.network.tailscale`. It runs its own
tailscaled as the user, in userspace networking mode, which creates no
network interface, no routes and no DNS changes, and exposes only a local
proxy. The remote-agent app is a Chrome app window with its own Chrome
profile that is pointed at that proxy; nothing else on the desktop is. The
node runs with shields up, so other tailnet devices cannot reach the desktop.

## Consequences

- Any other program that should reach the tailnet later has to be pointed at
  the proxy explicitly; enabling `features.network.tailscale` on the desktop
  would undo this decision.
- The app's Chrome profile is separate from the everyday Chrome profile:
  no shared logins, history or extensions.
- `tailscale` commands on the desktop need the user daemon's socket, not the
  system one.
