{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/mqtt";
in
with lib;
{
  config = mkIf config.features.homelab.mqtt.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/mqtt 0700 - - -"
      "d %h/.homelab/mqtt/config 0700 - - -"
      "d %h/.homelab/mqtt/data 0700 - - -"
    ];

    services.podman.networks.mqtt-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.mqtt = {
      image = "eclipse-mosquitto:2.0";
      network = [
        "z2m-network"
        "mqtt-network"
      ];

      volumes = [
        "${data_path}/config:/mosquitto/config"
        "${data_path}/data:/mosquitto/data"
      ];
      exec = "mosquitto -c /mosquitto-no-auth.conf";
    };
  };
}
