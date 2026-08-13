{ config, lib, ... }:
with lib;
let
  frigateStorage = config.settings.frigateStoragePath;
  mediaStorage = config.settings.mediaStoragePath;
  user = config.settings.username;
  hl = config.features.homelab;
in
{
  config = {
    # Each drive is single-purpose: the SSD holds Frigate recordings, the RAID
    # enclosure holds all ARR-stack media. See doc/adr/0002.
    systemd.tmpfiles.rules =
      optionals (frigateStorage != null) (
        [ "d ${frigateStorage}/.homelab 0700 ${user} users -" ]
        ++ optionals hl.frigate.enable [
          "d ${frigateStorage}/.homelab/frigate 0700 ${user} users -"
          "d ${frigateStorage}/.homelab/frigate/media 0700 ${user} users -"
        ]
      )
      ++ optionals (mediaStorage != null) (
        [ "d ${mediaStorage}/.homelab 0700 ${user} users -" ]
        ++ optionals hl.entertainment.sonarr.enable [
          "d ${mediaStorage}/.homelab/sonarr 0700 ${user} users -"
          "d ${mediaStorage}/.homelab/sonarr/tv 0755 ${user} users -"
        ]
        ++ optionals hl.entertainment.radarr.enable [
          "d ${mediaStorage}/.homelab/radarr 0700 ${user} users -"
          "d ${mediaStorage}/.homelab/radarr/movies 0755 ${user} users -"
        ]
        ++ optionals hl.entertainment.qbittorrent.enable [
          "d ${mediaStorage}/.homelab/qbittorrent 0700 ${user} users -"
          "d ${mediaStorage}/.homelab/qbittorrent/downloads 0777 ${user} users -"
        ]
      );
  };
}
