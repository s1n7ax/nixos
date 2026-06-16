# 1. Use /storage-hdd as secondary ARR media storage

- Status: Accepted
- Date: 2026-06-16
- Related: PR #48 (resilient `/storage-hdd` mount), PR #50 (this change), issue #49

## Context

The server has two data drives:

- `/storage` — internal SSD, the primary data drive for the homelab ARR stack.
- `/storage-hdd` — external RAID enclosure HDD, added in PR #48.

The enclosure is unreliable: it occasionally powers itself off and does not come
back on its own, and its ext4 filesystem periodically needs an fsck after an
unclean power loss. PR #48 therefore mounted it with completely non-blocking
options (`nofail`, `x-systemd.automount`, `device-timeout=1min`,
`idle-timeout=0`) so a bad enclosure never fails the server's boot nor wedges any
service. At that point `/storage-hdd` was only mounted and made available —
nothing consumed it.

We want the extra capacity of the HDD for the ARR stack (a second root folder /
save path) without giving up the resilience PR #48 bought.

## Decision

Wire `/storage-hdd` into the ARR stack as a *secondary* media drive, alongside
the SSD which remains primary:

- A `settings.storageHddPath` option (mirrors `settings.storagePath`), set to
  `/storage-hdd` on the server profile and `null` everywhere else.
- The same `.homelab` directory structure used on `/storage`
  (`sonarr/tv`, `radarr/movies`, `qbittorrent/downloads`) is replicated onto
  `/storage-hdd`.
- The ARR containers mount the HDD dirs as additional volumes, gated on
  `storageHddPath != null`:
  - sonarr → `/tv-hdd`, `/downloads-hdd`
  - radarr → `/movies-hdd`, `/downloads-hdd`
  - qbittorrent → `/downloads-hdd`
  - jellyfin → `/movies-hdd`, `/tv-hdd`

Keeping each drive's download and library dirs on the same filesystem preserves
hardlink / atomic-move support for content destined to that drive.

## Consequences

Positive:

- The ARR apps can use both drives as root folders; the HDD absorbs overflow the
  SSD cannot hold.
- Hosts without a second drive are unaffected (`storageHddPath` defaults to
  `null`, so no HDD volumes or directories are created).
- The SSD stays the default, so day-to-day behaviour is unchanged when the
  enclosure is healthy.

Negative — accepted trade-offs against PR #48's resilience:

- **Entertainment containers couple to the enclosure.** Because the ARR
  containers now bind-mount `/storage-hdd` subdirs, those containers fail to
  start while the enclosure is powered off (podman cannot resolve the automount
  source). This is contained to the entertainment stack — the services that
  actually need the drive — while the rest of the system stays resilient.
- **Boot can wait on the enclosure.** The `systemd-tmpfiles-setup` rules that
  create the HDD directories run at boot and touch `/storage-hdd`, triggering the
  automount. With the enclosure off, that access blocks up to the
  `device-timeout` (1 min) before failing. `nofail` keeps it non-fatal, so it is
  a boot *delay* in the failure case, not a boot failure.

## Revisiting

This is intentionally cheap to back out. If the enclosure fails often enough that
the coupling above becomes annoying, remove the secondary storage:

- Clear `settings.storageHddPath` on the server profile (set it back to `null`).
  That alone drops every HDD container volume and the HDD `tmpfiles` rules, since
  they are all gated on `storageHddPath != null`. The ARR apps fall back to the
  SSD-only `/storage` layout and stop waiting on the enclosure.
- Optionally also drop the `/storage-hdd` `fileSystems` entry from PR #48 if the
  enclosure is retired entirely.
