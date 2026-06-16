{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/radarr";
  storage_path = "${config.settings.storagePath}/.homelab/radarr";
  download_path = "${config.settings.storagePath}/.homelab/qbittorrent/downloads";
  hdd = config.settings.storageHddPath;
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.radarr.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/radarr 0700 - - -"
      "d %h/.homelab/radarr/config 0700 - - -"
    ];

    services.podman.containers.radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config:Z"
        "${storage_path}/movies:/movies:z"
        "${download_path}:/downloads:z"
      ]
      ++ optionals (hdd != null) [
        "${hdd}/.homelab/radarr/movies:/movies-hdd:z"
        "${hdd}/.homelab/qbittorrent/downloads:/downloads-hdd:z"
      ];

      environment = {
        PUID = 1000;
        PGID = 1000;
      };

      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];

      ports = [
        "7878:7878"
      ];
    };
  };
}
