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
      network = [
        "home-assistant-network"
        "frigate-network"
        "mqtt-network"
      ];
      volumes = [
        "${data_path}:/config"
        "/etc/localtime:/etc/localtime:ro"
        "/run/dbus:/run/dbus:ro"
      ];
      ports = [ "8124:8123" ];
      addCapabilities = [
        "NET_ADMIN"
        "NET_RAW"
      ];
    };
  };
}
