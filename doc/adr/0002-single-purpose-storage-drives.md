# 2. Give each storage drive a single purpose

- Status: Accepted
- Date: 2026-08-13
- Supersedes: [ADR 0001](0001-storage-hdd-secondary-arr-storage.md)

## Context

ADR 0001 made `/storage-hdd` a *secondary* ARR media drive alongside `/storage`,
so both drives carried ARR data and `/storage` additionally carried Frigate
recordings. That left two problems:

- **Split libraries.** Every ARR app saw two root folders / save paths
  (`/tv` + `/tv-hdd`, `/movies` + `/movies-hdd`, `/downloads` +
  `/downloads-hdd`). Where a given show or movie lived depended on which root
  folder was picked at grab time, and Jellyfin had to be told about both.
- **Frigate and the ARR stack competed for the SSD.** Frigate writes recordings
  continuously; the ARR stack writes large downloads in bursts. Both filling the
  same drive means either one can starve the other.

## Decision

Each drive gets exactly one consumer:

- `/storage` (internal SSD) — Frigate recordings only.
- `/storage-hdd` (RAID enclosure) — the whole ARR stack: sonarr, radarr,
  qbittorrent, and the libraries Jellyfin reads.

The two settings options are renamed to say what they are for, rather than which
device they happen to be:

- `settings.storagePath` → `settings.frigateStoragePath`
- `settings.storageHddPath` → `settings.mediaStoragePath`

Both default to `null` and are set on the server profile only.

The `-hdd` container volumes from ADR 0001 are gone. The ARR containers keep
their original mount points (`/tv`, `/movies`, `/downloads`) — only the host side
moves to `/storage-hdd` — so the apps' configured root folders and save paths
stay valid.

The directory layout under the media drive is defined once, as the internal
`settings.mediaPaths` option in `system/options.nix`. That file is imported into
both module systems (NixOS via `flake.nix`, home-manager via
`system/home-manager/default.nix`), so the module that *creates* the directories
and the container modules that *bind-mount* them read the same strings. Spelling
the layout out separately in each would drift silently: a mismatch raises no
evaluation error, podman simply creates the wrong directory and the app comes up
against an empty library.

## Consequences

Positive:

- One root folder per app, one library location per media type. No more choosing
  a drive per grab.
- Downloads and libraries all sit on one filesystem, so hardlinks and atomic
  moves work across the whole ARR stack.
- Frigate has the SSD to itself: ARR traffic can no longer fill the drive that
  holds recordings.

Negative:

- **The enclosure is now a single point of failure for the ARR data, not just
  for container startup.** ADR 0001 noted the enclosure powers itself off and
  occasionally needs an fsck. The containers already failed to start while it was
  down — under ADR 0001 they bind-mounted `/storage-hdd` subdirs too, which
  ADR 0001 recorded as an accepted cost — so that is not new here. What changes is
  that the SSD no longer holds a usable copy: previously a down enclosure cost
  access to the overflow half of a split library, now it costs access to all of
  it. Accepted deliberately: the blast radius is still the entertainment stack
  only — Frigate, Home Assistant, and the rest of the system stay up, and the
  mount options from PR #48 (`nofail`, `x-systemd.automount`) still keep boot
  non-fatal.
- **Existing ARR data on `/storage` becomes invisible** to the containers. It has
  to be moved to `/storage-hdd/.homelab/…` by hand (see Migration).
- ARR media is no longer on the SSD, so library reads are slower. Irrelevant for
  streaming playback.

## Migration

Not automated — the config change alone does not move any bytes, and **the order
matters**. `nixos-rebuild switch` is what restarts the containers onto the new
mount points, so it has to come *after* the data has moved. Deploying first
points Sonarr and Radarr at an empty library, so they mark everything missing and
re-grab monitored items; makes qBittorrent error or force-recheck every torrent
whose data was on `/storage`; and lets Jellyfin scan an empty library and drop
items along with their watch state.

On the server, still running the currently deployed configuration:

1. Stop the stack so nothing writes during the copy:

   ```sh
   systemctl --user stop podman-{sonarr,radarr,qbittorrent,jellyfin}
   ```

2. Move the ARR trees in a **single hardlink-preserving pass** — one `rsync`
   rooted at `/storage/.homelab/`, not three separate `mv`s. A cross-filesystem
   `mv` copies and unlinks, so moving the download and library trees
   independently would turn every hardlinked pair into two independent files:
   roughly double the space on `/storage-hdd`, and qBittorrent's copy would no
   longer be the inode Sonarr imported, so removing a torrent would stop freeing
   space. The filters keep `frigate/` on the SSD where it belongs:

   ```sh
   rsync -aHAX --remove-source-files \
     --include='/sonarr/***' \
     --include='/radarr/***' \
     --include='/qbittorrent/***' \
     --exclude='*' \
     /storage/.homelab/ /storage-hdd/.homelab/
   ```

   `-H` only reconciles hardlinks *within one transfer set*, which is why all
   three trees must go across in the same invocation.

3. Deploy this configuration, which restarts the containers on the new paths:

   ```sh
   sudo nixos-rebuild switch --flake .#server
   ```

4. Drop the now-dead `-hdd` root folders / save paths in the Sonarr, Radarr, and
   qBittorrent UIs, and the `-hdd` libraries in Jellyfin.

5. Remove the empty directories `--remove-source-files` leaves behind:

   ```sh
   find /storage/.homelab/{sonarr,radarr,qbittorrent} -depth -type d -empty -delete
   ```

## Revisiting

If the enclosure becomes too unreliable to host the whole ARR stack, point
`settings.mediaStoragePath` back at `/storage` (or a new drive) and move the data
with it. Nothing else in the config needs to change — no service references the
drives except through these two options.
