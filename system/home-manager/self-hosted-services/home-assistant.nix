{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/home-assistant";
in
with lib;
{
  config = mkIf config.features.homelab.home-assistant.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/home-assistant 0700 - - -"
    ];

    services.podman.networks.home-assistant-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      # using this because of issue https://github.com/blakeblackshear/frigate-hass-integration/issues/790
      # image = "ghcr.io/home-assistant/home-assistant:2025.8.1";
      autoUpdate = "registry";
      network = [
        "home-assistant-network"
        "frigate-network"
        "mqtt-network"
      ];
      volumes = [
        "${data_path}:/config"
        "/run/dbus:/run/dbus:ro"
        # The security_alerts integration, read-only from this repo. A new store
        # path changes the unit, so a deploy that changes it restarts HA.
        "${./home-assistant/security_alerts}:/config/custom_components/security_alerts:ro"
        # The house_model integration: serves the 3D house dashboard card.
        "${./home-assistant/house_model}:/config/custom_components/house_model:ro"
        # The energy_meters integration: keeps the Energy dashboard's device list in sync.
        "${./home-assistant/energy_meters}:/config/custom_components/energy_meters:ro"
      ];
      extraPodmanArgs = [ "--tz=local" ];
      # Loopback only: the host Caddy (nixos/self-hosted-services/home-assistant-proxy.nix)
      # serves :8124 so HA sees real client IPs.
      ports = [ "127.0.0.1:8123:8123" ];
      addCapabilities = [
        "NET_ADMIN"
        "NET_RAW"
      ];
    };
  };
}
