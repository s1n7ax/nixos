{
  config,
  lib,
  ...
}:
with lib;
{
  config = mkIf config.features.homelab.pairdrop.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/pairdrop 0750 - - -"
    ];

    services.podman.containers.pairdrop = {
      image = "lscr.io/linuxserver/pairdrop:latest";
      ports = [
        "3002:3000"
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = config.home.timeZone or "UTC";
      };
      volumes = [
        "${config.home.homeDirectory}/.homelab/pairdrop:/config:Z"
      ];
      autoStart = true;
    };
  };
}
