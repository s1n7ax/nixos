{ config, lib, ... }:
with lib;
{
  config = mkIf config.features.homelab.frigate.enable {
    services.podman.containers.mqtt = {
      image = "eclipse-mosquitto:2.0";
      network = [ "frigate-network" ];
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
      ];
      exec = "mosquitto -c /mosquitto-no-auth.conf";
    };
  };
}
