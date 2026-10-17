{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/wyoming-piper";
in
with lib;
{
  config = mkIf config.features.homelab.wyoming-piper.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/wyoming-piper 0700 - - -"
    ];

    services.podman.containers.wyoming-piper = {
      image = "docker.io/rhasspy/wyoming-piper:latest";
      autoUpdate = "registry";
      network = [ "home-assistant-network" ];
      volumes = [ "${data_path}:/data" ];
      extraPodmanArgs = [ "--tz=local" ];
      exec = "--voice en_US-lessac-medium";
    };
  };
}
