{
  config,
  lib,
  pkgs,
  ...
}:
# The remote-agent app (doc/adr/0003): a Chrome app window for the
# remote-agent board, and the only thing on the machine that reaches the
# tailnet. tailscaled runs as the user in userspace networking mode, so it
# creates no network interface, routes or DNS settings and only offers a
# SOCKS5 proxy on 127.0.0.1, which the app's own Chrome profile uses. Shields
# up: other tailnet devices cannot reach this machine.
#
# First sign-in: click the top bar's Tailscale item while it shows "needs
# sign-in" (or `tailscale up --shields-up --hostname=<hostname>`). The
# `tailscale` command talks to this daemon.
#
# Journal: `journalctl --user -u remote-agent-tailscaled`.
let
  cfg = config.features.desktop.remote-agent;

  remote-agent = pkgs.callPackage ./package.nix {
    inherit (cfg) url hostname proxyPort;
  };

  # The tailscale CLI, pointed at the user daemon's socket.
  tailscale = pkgs.writeShellScriptBin "tailscale" ''
    exec ${pkgs.tailscale}/bin/tailscale --socket="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tailscale/tailscaled.sock" "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.features.network.tailscale.enable;
        message = "features.desktop.remote-agent keeps the tailnet to the remote-agent app (doc/adr/0003); it cannot be combined with the system-wide features.network.tailscale.";
      }
    ];

    home.packages = [
      remote-agent
      tailscale
    ];

    systemd.user.services.remote-agent-tailscaled = {
      Unit.Description = "Tailscale for the remote-agent app (userspace networking, SOCKS5 proxy only)";
      Service = {
        # %S/tailscale and %t/tailscale are the StateDirectory and
        # RuntimeDirectory below (~/.local/state, $XDG_RUNTIME_DIR).
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.tailscale}/bin/tailscaled"
          "--tun=userspace-networking"
          "--socks5-server=127.0.0.1:${toString cfg.proxyPort}"
          "--statedir=%S/tailscale"
          "--socket=%t/tailscale/tailscaled.sock"
        ];
        StateDirectory = "tailscale";
        RuntimeDirectory = "tailscale";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    xdg.desktopEntries.remote-agent = {
      name = "Remote Agent";
      comment = "The remote-agent board, over the tailnet";
      exec = "${remote-agent}/bin/remote-agent open";
      icon = "applications-internet";
      terminal = false;
      categories = [
        "Network"
        "Development"
      ];
    };
  };
}
