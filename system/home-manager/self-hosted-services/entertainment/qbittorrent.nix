{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/qbittorrent";
  storage_path = "${config.settings.storagePath}/.homelab/qbittorrent";
  hdd = config.settings.storageHddPath;
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.qbittorrent.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/qbittorrent 0700 - - -"
      "d %h/.homelab/qbittorrent/config 0755 - - -"
    ];

    services.podman.containers.qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      network = [ "entertainment-network" ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        # if you want to change the host port, make sure the container port is the same
        # just mapping host to a different container port won't work
        WEBUI_PORT = "8001";
        TORRENTING_PORT = "6881";
      };

      volumes = [
        "${data_path}/config:/config"
        "${storage_path}/downloads:/downloads:z"
      ]
      ++ optionals (hdd != null) [
        "${hdd}/.homelab/qbittorrent/downloads:/downloads-hdd:z"
      ];

      ports = [
        "8001:8001"
        "6881:6881"
        "6881:6881/udp"
      ];

      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
        "--stop-timeout 10"
      ];
    };
  };
}
