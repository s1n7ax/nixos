{
  config,
  lib,
  ...
}:
with lib;
{
  config = mkIf config.features.homelab.filepizza.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/filepizza 0750 - - -"
    ];

    services.podman.networks.filepizza-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.filepizza = {
      image = "docker.io/kern/filepizza:latest";
      network = [ "filepizza-network" ];
      ports = [
        "3002:3000"
      ];
      environment = {
        PORT = "3000";
      };
      autoStart = true;
    };
  };
}
