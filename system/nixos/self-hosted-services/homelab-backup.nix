{
  config,
  lib,
  pkgs,
  ...
}:
# Uploads an encrypted backup of the homelab services' settings and data to
# the homelab's own Dropbox App folder before every rebuild that applies a
# configuration (switch, test, boot), however the rebuild is started. A failed
# backup stops the rebuild before anything is applied. Nothing is ever
# deleted or overwritten on Dropbox; old backups are pruned by hand.
#
# Skip once (e.g. offline): `sudo touch /run/skip-homelab-backup`.
# nixos-install of a new homelab backs up nothing (there is nothing yet).
# Setup (Dropbox app, token) and restore: doc/homelab-backup.md.
let
  hl = config.features.homelab;
  ent = hl.entertainment;
  username = config.settings.username;
  homelab = "${config.users.users.${username}.home}/.homelab";

  # The *arr apps' logs, log database, cover art, scheduled backups, crash
  # reports and pid file.
  arrExclude = [
    "logs"
    "logs.db*"
    "MediaCover"
    "Backups"
    "Sentry"
    "*.pid"
  ];

  # What each service keeps: its settings and its own database, plus Paperless
  # documents, Home Assistant history and Frigate events. Media, downloads,
  # recordings, snapshots, logs, caches, cover art, existing backups and
  # re-downloadable things stay out. `databases` are SQLite files, captured as
  # consistent snapshots; `exclude` entries are globs relative to `path`
  # (`*` matches `/` too).
  sources = [
    {
      enable = ent.sonarr.enable;
      name = "sonarr";
      path = "${homelab}/sonarr/config";
      databases = [ "sonarr.db" ];
      exclude = arrExclude;
    }
    {
      enable = ent.radarr.enable;
      name = "radarr";
      path = "${homelab}/radarr/config";
      databases = [ "radarr.db" ];
      exclude = arrExclude;
    }
    {
      enable = ent.prowlarr.enable;
      name = "prowlarr";
      path = "${homelab}/prowlarr/config";
      databases = [ "prowlarr.db" ];
      # Definitions: the indexer definitions Prowlarr downloads itself.
      exclude = arrExclude ++ [ "Definitions" ];
    }
    {
      enable = ent.qbittorrent.enable;
      name = "qbittorrent";
      path = "${homelab}/qbittorrent/config";
      databases = [ ];
      exclude = [
        ".cache"
        "qBittorrent/logs"
        "qBittorrent/GeoDB"
        "qBittorrent/lockfile"
      ];
    }
    {
      enable = ent.jellyfin.enable;
      name = "jellyfin";
      path = "${homelab}/jellyfin/config";
      databases = [ "data/data/jellyfin.db" ];
      exclude = [
        "cache"
        ".cache"
        "log"
        # Posters and other artwork.
        "data/metadata"
        "data/transcodes"
        "data/data/SQLiteBackups"
        "data/data/splashscreen.png"
        # Extracted subtitle cache.
        "data/data/subtitles"
      ];
    }
    {
      enable = hl.home-assistant.enable;
      name = "home-assistant";
      path = "${homelab}/home-assistant";
      # Recorder history and the security_alerts alert list.
      databases = [
        "home-assistant_v2.db"
        "security_alerts/alerts.db"
      ];
      exclude = [
        "backups"
        # security_alerts snapshots.
        "security_alerts/media"
        # Python packages HA installs itself.
        "deps"
        "*/__pycache__"
        ".cache"
        "tts"
        "home-assistant.log*"
        ".ha_run.lock"
      ];
    }
    {
      enable = hl.node-red.enable;
      name = "node-red";
      path = "${homelab}/node-red";
      databases = [ ];
      # Installed nodes; package.json lists them for `npm install`.
      exclude = [
        "node_modules"
        ".npm"
      ];
    }
    {
      enable = hl.z2m.enable;
      name = "z2m";
      path = "${homelab}/z2m";
      databases = [ ];
      exclude = [
        "log"
        # A link into the Nix store, written by the z2m module.
        "configuration.yaml"
      ];
    }
    {
      enable = hl.mqtt.enable;
      name = "mqtt";
      path = "${homelab}/mqtt";
      databases = [ ];
      exclude = [ ];
    }
    {
      enable = hl.frigate.enable;
      name = "frigate";
      # Only the event database lives here; config.yaml comes from this repo
      # and the recordings from settings.frigateStoragePath.
      path = "${homelab}/frigate/config";
      databases = [ "frigate.db" ];
      # Frigate's own copy from before its last migration.
      exclude = [ "backup.db*" ];
    }
    {
      enable = hl.paperless.enable;
      name = "paperless";
      path = "${homelab}/paperless";
      databases = [ "data/db.sqlite3" ];
      exclude = [
        "data/log"
        # Search index (`document_index reindex`) and the auto-tagging model
        # (retrained hourly).
        "data/index"
        "data/classification_model.pickle"
        "data/celerybeat-schedule.db*"
        "media/media.lock"
        # Output of Paperless' own exporter.
        "export"
        # Task queue.
        "redis"
      ];
    }
    {
      enable = hl.adguard.enable;
      name = "adguard";
      # Settings only: work/ holds statistics, the query log and downloaded
      # filter lists.
      path = "/opt/adguard/conf";
      databases = [ ];
      exclude = [ ];
    }
    {
      enable = hl.dongle-m-reboot-monitor.enable;
      name = "dongle-m-reboot-monitor";
      path = "/var/lib/dongle-m-reboot-monitor";
      databases = [ ];
      exclude = [ ];
    }
  ];

  spec = pkgs.writeText "homelab-backup-spec.json" (
    builtins.toJSON {
      sources = map (source: removeAttrs source [ "enable" ]) (
        lib.filter (source: source.enable) sources
      );
    }
  );

  # The user's sops age keys (s1n7ax_desktop and s1n7ax_server in
  # nix-secrets' .sops.yaml), so a backup opens with the desktop key alone.
  recipients = [
    "age1lzy76q95cn2q56gpst8u6w2srgyarvte2hxt0duvvglku7w0xfvqmzdmk7"
    "age1xwqsadmu2vzhvwj6chs9z7xecy6h2m5yn0hgnpjac3hjk58dk9gs0cvp6q"
  ];

  env = {
    HOMELAB_BACKUP_SPEC = "${spec}";
    HOMELAB_BACKUP_RECIPIENTS = lib.concatStringsSep "\n" recipients;
    HOMELAB_BACKUP_REMOTE = "homelab:";
    HOMELAB_BACKUP_SKIP_FILE = "/run/skip-homelab-backup";
    # Missing in nixos-install's chroot, where a new homelab has nothing to
    # back up yet.
    HOMELAB_BACKUP_BOOTED_MARKER = "/run/systemd/system";
    HOMELAB_BACKUP_TMPDIR = "/var/tmp";
    # The Dropbox app (client_id, client_secret) and its token, read from the
    # incoming configuration's sops file with the keys sops-nix uses.
    HOMELAB_BACKUP_SOPS_FILE = "${config.sops.defaultSopsFile}";
    HOMELAB_BACKUP_SOPS_KEY = "rclone/dropbox-homelab";
    HOMELAB_BACKUP_SSH_KEYS = lib.concatStringsSep "\n" config.sops.age.sshKeyPaths;
    HOMELAB_BACKUP_AGE_KEY_FILE = lib.optionalString (
      config.sops.age.keyFile != null
    ) config.sops.age.keyFile;
  };

  backup = pkgs.callPackage ./homelab-backup/package.nix { };
in
{
  config = lib.mkIf hl.backup.enable {
    # Checks run in name order; this one sorts after nixpkgs' switchInhibitors,
    # so a switch that check refuses fails before the upload, not after it.
    system.preSwitchChecks.zz-homelab-backup =
      lib.concatStrings (
        lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") env
      )
      + ''
        ${lib.getExe backup} pre-switch "$@"
      '';
  };
}
