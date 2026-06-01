{
  config,
  lib,
  ...
}:
with lib;
{
  config = mkIf config.features.homelab.node-red.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/node-red 0750 - - -"
    ];

    services.podman.containers.node-red = {
      image = "nodered/node-red:latest";
      network = [
        "home-assistant-network"
        "mqtt-network"
      ];
      ports = [
        "1880:1880"
      ];
      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];
      volumes = [
        "${config.home.homeDirectory}/.homelab/node-red:/data:Z"
      ];
      autoStart = true;
    };
  };
}
