# /storage-hdd — the external RAID enclosure HDD, mounted as a second drive
# alongside the internal /storage SSD.
#
# The enclosure is unreliable: it occasionally powers itself off (and does not
# come back on its own), and its ext4 filesystem periodically needs an fsck after
# an unclean loss of power. It is mounted with completely non-blocking options so
# a bad enclosure never fails the server's boot nor wedges any service.
#
# The *arr stack still lives on the /storage SSD; for now this drive is only
# mounted and made available. If something is later pointed at /storage-hdd, the
# autofs behaviour below also gives it correct mount ordering for free.
#
#   nofail                        Boot never fails because of this mount.
#
#   x-systemd.automount + noauto  Mount lazily on first access instead of at boot,
#                                 so boot proceeds immediately and nothing waits on
#                                 the enclosure spinning up. The first access to
#                                 /storage-hdd transparently blocks until the real
#                                 fs is mounted, so a consumer can never write into
#                                 an empty /storage-hdd on the root disk and then be
#                                 shadowed when the drive mounts later.
#
#   x-systemd.device-timeout=1min How long to wait for the slow/flaky enclosure to
#                                 present its device node before giving up. If the
#                                 enclosure is switched off, an access fails after a
#                                 minute instead of hanging forever.
#
#   x-systemd.idle-timeout=0      Never auto-unmount while idle (0 = disabled), so a
#                                 long-lived consumer's bind mount can't go stale.
#
# fsck: systemd-fsck@.service ships with TimeoutSec=infinity, so a legitimate
# repair is allowed to run to completion — this is the "wait for the fix to take
# place" behaviour. e2fsck runs in the default preen mode; if the filesystem is too
# damaged to repair automatically it bails, and thanks to nofail the mount is simply
# skipped rather than blocking the boot.
{ ... }:
{
  fileSystems."/storage-hdd" = {
    device = "/dev/disk/by-uuid/58670f4d-422d-4fbc-b179-78c0cb8d0e5b";
    fsType = "ext4";
    options = [
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.device-timeout=1min"
      "x-systemd.idle-timeout=0"
    ];
  };
}
