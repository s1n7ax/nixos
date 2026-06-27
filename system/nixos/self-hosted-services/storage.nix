{ config, lib, ... }:
with lib;
let
  sp = config.settings.storagePath;
  hdd = config.settings.storageHddPath;
  user = config.settings.username;
  hl = config.features.homelab;

  # ARR-stack media directories, replicated on each storage backend (the primary
  # /storage SSD and the secondary /storage-hdd RAID enclosure) so the apps can
  # use both drives as root folders / save paths.
  arrRules = base:
    optionals hl.entertainment.sonarr.enable [
      "d ${base}/.homelab/sonarr 0700 ${user} users -"
      "d ${base}/.homelab/sonarr/tv 0755 ${user} users -"
    ]
    ++ optionals hl.entertainment.radarr.enable [
      "d ${base}/.homelab/radarr 0700 ${user} users -"
      "d ${base}/.homelab/radarr/movies 0755 ${user} users -"
    ]
    ++ optionals hl.entertainment.qbittorrent.enable [
      "d ${base}/.homelab/qbittorrent 0700 ${user} users -"
      "d ${base}/.homelab/qbittorrent/downloads 0777 ${user} users -"
    ];
in
{
  config = mkIf (sp != null) {
    systemd.tmpfiles.rules = [
      "d ${sp}/.homelab 0700 ${user} users -"
    ]
    ++ optionals hl.frigate.enable [
      "d ${sp}/.homelab/frigate 0700 ${user} users -"
      "d ${sp}/.homelab/frigate/media 0700 ${user} users -"
    ]
    ++ arrRules sp
    ++ optionals (hdd != null) (
      [ "d ${hdd}/.homelab 0700 ${user} users -" ] ++ arrRules hdd
    );
  };
}
