{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/sonarr";
  download_path = "${config.home.homeDirectory}/.homelab/qbittorrent/downloads";
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.sonarr.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/sonarr 0700 - - -"
      "d %h/.homelab/sonarr/config 0700 - - -"
      "d %h/.homelab/sonarr/tv 0700 - - -"
      "d %h/.homelab/sonarr/downloads 0700 - - -"
    ];

    services.podman.containers.sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config:Z"
        "${data_path}/tv:/tv"
        "${download_path}:/downloads"
      ];

      environment = {
        PUID = 1000;
        PGID = 1000;
        TZ = Etc/UTC;
      };

      ports = [
        "8989:8989"
      ];
    };
  };
}
