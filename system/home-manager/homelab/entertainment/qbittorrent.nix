{ config, lib, ... }:
let
  data_path = "${config.home.homeDirectory}/.homelab/qbittorrent";
  storage_path = "${config.settings.storagePath}/.homelab/qbittorrent";
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.qbittorrent.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/qbittorrent 0700 - - -"
      "d %h/.homelab/qbittorrent/config 0700 - - -"
      "d ${config.settings.storagePath}/.homelab 0700 - - -"
      "d ${config.settings.storagePath}/.homelab/qbittorrent 0700 - - -"
      "d ${config.settings.storagePath}/.homelab/qbittorrent/downloads 0700 - - -"
    ];

    services.podman.containers.qbittorrent = {
      image = "qbittorrentofficial/qbittorrent-nox:5.1.0-1";
      network = [ "entertainment-network" ];

      volumes = [
        "${data_path}/config:/config"
        "${storage_path}/downloads:/downloads"
      ];

      environment = {
        QBT_LEGAL_NOTICE = "confirm";
        QBT_WEBUI_PORT = "8001";
      };

      ports = [
        "8001:8001"
        "6881:6881"
        "6881:6881/udp"
      ];

      extraPodmanArgs = [
        "--read-only"
        "--tmpfs /tmp:ro"
        "--stop-timeout 1800"
      ];
    };
  };
}
