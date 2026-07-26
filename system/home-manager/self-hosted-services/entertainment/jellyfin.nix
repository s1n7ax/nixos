{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/jellyfin";
  movie_path = "${config.settings.storagePath}/.homelab/radarr/movies";
  tv_path = "${config.settings.storagePath}/.homelab/sonarr/tv";
  hdd = config.settings.storageHddPath;
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
        "${data_path}/config:/config:Z"
        "${movie_path}:/movies:z"
        "${tv_path}:/tv:z"
      ]
      ++ optionals (hdd != null) [
        "${hdd}/.homelab/radarr/movies:/movies-hdd:z"
        "${hdd}/.homelab/sonarr/tv:/tv-hdd:z"
      ];

      environment = {
        PUID = 1000;
        PGID = 1000;
      };

      extraPodmanArgs = [ "--tz=local" ];

      ports = [
        "8096:8096"
      ];
    };
  };
}
