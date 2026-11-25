# s1n7ax's NixOS configuration

The NixOS and nix-darwin configuration for one person's machines: the desktop, the homelab server, the orangepi and the MacBook.

## Language

**Desktop**:
The NixOS desktop PC running Hyprland, built from the `desktop` profile. Never the MacBook.
_Avoid_: PC, workstation

**Remote-agent board**:
The remote-agent web app, served on the tailnet at `remote-agent.tail73fb28.ts.net`, where agent tickets are tracked.
_Avoid_: remote agent, the board site

**Remote-agent app**:
The Chrome app window on the desktop that opens the remote-agent board; the only thing on the desktop that reaches the tailnet.
_Avoid_: remote-agent launcher, the Chrome app

**Top bar**:
The status bar along the top of every monitor on the desktop.
_Avoid_: panel, status bar, Waybar
