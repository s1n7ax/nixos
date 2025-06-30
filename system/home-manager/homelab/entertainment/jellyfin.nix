{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/jellyfin";
  movie_path = "${config.home.homeDirectory}/.homelab/radarr/movies";
  tv_path = "${config.home.homeDirectory}/.homelab/sonarr/tv";
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.jellyfin.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/jellyfin 0700 - - -"
      "d %h/.homelab/jellyfin/config 0700 - - -"
    ];

    services.podman.containers.jellyfin = {
      image = "lscr.io/linuxserver/jellyfin:latest";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config"
        "${movie_path}:/movies"
        "${tv_path}:/tv"
      ];

      environment = {
        PUID = 1000;
        PGID = 1000;
        TZ = Etc/UTC;
      };

      ports = [
        "8096:8096"
      ];
    };
  };
}
