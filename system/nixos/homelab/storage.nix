{ config, lib, ... }:
with lib;
let
  sp = config.settings.storagePath;
  user = config.settings.username;
  hl = config.features.homelab;
in
{
  config = mkIf (sp != null) {
    systemd.tmpfiles.rules =
      [ "d ${sp}/.homelab 0700 ${user} users -" ]
      ++ optionals hl.frigate.enable [
        "d ${sp}/.homelab/frigate 0700 ${user} users -"
        "d ${sp}/.homelab/frigate/media 0700 ${user} users -"
      ]
      ++ optionals hl.entertainment.sonarr.enable [
        "d ${sp}/.homelab/sonarr 0700 ${user} users -"
        "d ${sp}/.homelab/sonarr/tv 0755 ${user} users -"
      ]
      ++ optionals hl.entertainment.radarr.enable [
        "d ${sp}/.homelab/radarr 0700 ${user} users -"
        "d ${sp}/.homelab/radarr/movies 0755 ${user} users -"
      ]
      ++ optionals hl.entertainment.qbittorrent.enable [
        "d ${sp}/.homelab/qbittorrent 0700 ${user} users -"
        "d ${sp}/.homelab/qbittorrent/downloads 0700 ${user} users -"
      ];
  };
}
