{ config, lib, ... }:
# Fronts Home Assistant on :8124 so HA sees each client's real IP. Rootless
# podman's port forwarding rewrites every source address to the container's
# own, which hides who sent a request (e.g. in HA's invalid-authentication
# notifications). HA itself is published on 127.0.0.1:8123 only, and its HTTP
# settings (stored in HA, not YAML) trust X-Forwarded-For from 10.89.0.0/16.
#
# Caddy, not nginx: the WireGuard quadlet's nginx container already owns
# nginx.service.
with lib;
{
  config = mkIf config.features.homelab.home-assistant.enable {
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts.":8124".extraConfig = ''
        reverse_proxy 127.0.0.1:8123
      '';
    };

    # Can start before the home-manager switch frees :8124 from podman; a bind
    # failure exits 1, which the upstream unit would not restart.
    systemd.services.caddy = {
      startLimitIntervalSec = mkForce 0;
      serviceConfig = {
        Restart = mkForce "always";
        RestartPreventExitStatus = mkForce "";
      };
    };
  };
}
