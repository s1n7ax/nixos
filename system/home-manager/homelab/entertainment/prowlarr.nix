{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/prowlarr";
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.prowlarr.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/prowlarr 0700 - - -"
      "d %h/.homelab/prowlarr/config 0700 - - -"
    ];

    services.podman.containers.prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config:Z"
      ];

      environment = {
        PUID = 1000;
        PGID = 1000;
        TZ = Etc/UTC;
      };

      ports = [
        "9696:9696"
      ];
    };

    services.podman.containers.flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      network = [ "entertainment-network" ];

      environment = {
        LOG_LEVEL = "info";
        LOG_HTML = "false";
        CAPTCHA_SOLVER = "none";
        TZ = "Etc/UTC";
      };
    };
  };
}
