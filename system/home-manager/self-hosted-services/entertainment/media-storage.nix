{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  ent = config.features.homelab.entertainment;
  media = config.settings.mediaPaths;
  mediaStorage = config.settings.mediaStoragePath;

  /**
    Gate for containers that bind-mount the RAID enclosure.

    The enclosure is mounted with `x-systemd.automount` (see doc/adr/0001), so
    nothing mounts it at boot -- the kernel only attempts the real mount once a
    process walks into the path. Reading `mediaPaths.root` does that walk, so
    this both triggers the attempt and waits for its outcome. `noautofs` is what
    makes the check meaningful: the autofs trigger point is itself a mount, so a
    plain mountpoint test passes even while the drive is down.
  */
  waitForMediaStorage = pkgs.writeShellScript "wait-for-media-storage" ''
    ${pkgs.coreutils}/bin/ls "${media.root}" > /dev/null 2>&1 || true

    if ! ${pkgs.util-linux}/bin/findmnt --noheadings --types noautofs \
      --mountpoint "${mediaStorage}" > /dev/null; then
      echo "${mediaStorage} is not mounted; is the RAID enclosure powered on?" >&2
      exit 1
    fi
  '';

  /**
    Restart policy that survives a drive that is late or absent.

    Podman cannot resolve a bind-mount source on an unmounted drive, so these
    containers fail within milliseconds of starting. The generated unit already
    carries `Restart=always`, but with systemd's default 100ms `RestartSec` that
    burns the default start limit (5 starts in 10s) almost instantly and leaves
    the unit permanently failed -- which is why the stack stays down after a
    boot where the enclosure was not ready, even once the drive comes back.
    Backing the restarts off and dropping the limit turns that into a retry loop
    that heals itself the moment the mount succeeds.

    `TimeoutStartSec` has to clear the mount's `x-systemd.device-timeout=1min`,
    since `waitForMediaStorage` blocks in the automount for up to that long.
  */
  mediaConsumer = {
    extraConfig = {
      Unit.StartLimitIntervalSec = 0;
      Service = {
        ExecStartPre = "${waitForMediaStorage}";
        RestartSec = 30;
        TimeoutStartSec = 180;
      };
    };
  };

  mediaConsumers =
    optional ent.sonarr.enable "sonarr"
    ++ optional ent.radarr.enable "radarr"
    ++ optional ent.qbittorrent.enable "qbittorrent"
    ++ optional ent.jellyfin.enable "jellyfin";
in
{
  config = mkIf (ent.enable && mediaStorage != null) {
    services.podman.containers = genAttrs mediaConsumers (_: mediaConsumer);
  };
}
