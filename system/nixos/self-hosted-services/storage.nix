{ config, lib, ... }:
with lib;
let
  frigateStorage = config.settings.frigateStoragePath;
  mediaStorage = config.settings.mediaStoragePath;
  media = config.settings.mediaPaths;
  user = config.settings.username;
  hl = config.features.homelab;
  ent = hl.entertainment;

  # Jellyfin only reads the sonarr/radarr libraries, so it counts as a consumer
  # of those directories even when the producing app is disabled.
  needsTv = ent.sonarr.enable || ent.jellyfin.enable;
  needsMovies = ent.radarr.enable || ent.jellyfin.enable;
  needsMedia = needsTv || needsMovies || ent.qbittorrent.enable;

  dir = mode: path: "d ${path} ${mode} ${user} users -";

  # Only create the media tree when something actually consumes it: the rules run
  # at boot and touching the path triggers the enclosure's automount, which
  # stalls up to its device-timeout when the enclosure is powered off.
  mediaRules = optionals (mediaStorage != null && needsMedia) (
    optionals needsTv [
      (dir "0700" media.sonarr)
      (dir "0755" media.tv)
    ]
    ++ optionals needsMovies [
      (dir "0700" media.radarr)
      (dir "0755" media.movies)
    ]
    ++ optionals ent.qbittorrent.enable [
      (dir "0700" media.qbittorrent)
      (dir "0777" media.downloads)
    ]
  );

  frigateRules = optionals (frigateStorage != null && hl.frigate.enable) [
    (dir "0700" "${frigateStorage}/.homelab/frigate")
    (dir "0700" "${frigateStorage}/.homelab/frigate/media")
  ];

  # Deduplicated so that pointing both options at one drive (the ADR 0002
  # rollback) does not emit the same rule twice.
  roots = unique (
    optional (frigateStorage != null) "${frigateStorage}/.homelab"
    ++ optional (mediaStorage != null && needsMedia) media.root
  );
in
{
  config = {
    # Each drive is single-purpose: the SSD holds Frigate recordings, the RAID
    # enclosure holds all ARR-stack media. See doc/adr/0002.
    assertions = [
      {
        assertion = needsMedia -> mediaStorage != null;
        message = ''
          settings.mediaStoragePath must be set when the entertainment stack
          (sonarr/radarr/qbittorrent/jellyfin) is enabled -- the ARR containers
          bind-mount their libraries and downloads from it.
        '';
      }
      {
        assertion = hl.frigate.enable -> frigateStorage != null;
        message = ''
          settings.frigateStoragePath must be set when features.homelab.frigate
          is enabled -- Frigate writes its recordings there.
        '';
      }
    ];

    systemd.tmpfiles.rules = map (dir "0700") roots ++ frigateRules ++ mediaRules;
  };
}
