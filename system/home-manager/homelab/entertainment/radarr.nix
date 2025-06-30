{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/radarr";
  download_path = "${config.home.homeDirectory}/.homelab/qbittorrent/downloads";
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.radarr.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/radarr 0700 - - -"
      "d %h/.homelab/radarr/config 0700 - - -"
      "d %h/.homelab/radarr/movies 0700 - - -"
      "d %h/.homelab/radarr/downloads 0700 - - -"
    ];

    services.podman.containers.radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config:Z"
        "${data_path}/movies:/movies"
        "${download_path}:/downloads"
      ];

      environment = {
        PUID = 1000;
        PGID = 1000;
        TZ = Etc/UTC;
      };

      ports = [
        "7878:7878"
      ];
    };
  };
}
