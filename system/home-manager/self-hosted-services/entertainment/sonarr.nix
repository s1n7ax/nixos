{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/sonarr";
  storage_path = "${config.settings.storagePath}/.homelab/sonarr";
  download_path = "${config.settings.storagePath}/.homelab/qbittorrent/downloads";
  hdd = config.settings.storageHddPath;
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.sonarr.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/sonarr 0700 - - -"
      "d %h/.homelab/sonarr/config 0700 - - -"
    ];

    services.podman.containers.sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config:Z"
        "${storage_path}/tv:/tv:z"
        "${download_path}:/downloads:z"
      ]
      ++ optionals (hdd != null) [
        "${hdd}/.homelab/sonarr/tv:/tv-hdd:z"
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
        "8989:8989"
      ];
    };
  };
}
