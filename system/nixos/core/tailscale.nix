{ lib, config, ... }:
with lib;
{
  # Remote access to the homelab over the hosted Tailscale tailnet. The node is
  # signed in once by hand (`sudo tailscale up`); tailscaled keeps its state in
  # /var/lib/tailscale, so it rejoins on every boot.
  config = mkIf config.features.network.tailscale.enable {
    services.tailscale.enable = true;

    # Tailnet devices reach every service the host serves, as on the LAN.
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };
}
