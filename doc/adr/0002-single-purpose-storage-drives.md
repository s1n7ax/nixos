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

## Consequences

Positive:

- One root folder per app, one library location per media type. No more choosing
  a drive per grab.
- Downloads and libraries all sit on one filesystem, so hardlinks and atomic
  moves work across the whole ARR stack.
- Frigate has the SSD to itself: ARR traffic can no longer fill the drive that
  holds recordings, and Frigate no longer touches the flaky enclosure at all.

Negative:

- **The entertainment stack now hard-depends on the enclosure.** ADR 0001 noted
  the enclosure powers itself off and occasionally needs an fsck. Previously the
  ARR apps could still serve the SSD copy while it was down; now sonarr, radarr,
  qbittorrent, and jellyfin all fail to start until it comes back. Accepted
  deliberately: the blast radius is the entertainment stack only — Frigate,
  Home Assistant, and the rest of the system stay up, and the mount options from
  PR #48 (`nofail`, `x-systemd.automount`) still keep boot non-fatal.
- **Existing ARR data on `/storage` becomes invisible** to the containers. It has
  to be moved to `/storage-hdd/.homelab/…` by hand (see Migration).
- ARR media is no longer on the SSD, so library reads are slower. Irrelevant for
  streaming playback.

## Migration

Not automated — the config change alone does not move any bytes. On the server,
with the entertainment stack stopped:

1. Move `/storage/.homelab/{sonarr/tv,radarr/movies,qbittorrent/downloads}` into
   the matching directories under `/storage-hdd/.homelab/`, merging with what is
   already there.
2. Drop the now-dead `-hdd` root folders / save paths in the Sonarr, Radarr, and
   qBittorrent UIs, and the `-hdd` libraries in Jellyfin.
3. Remove the leftover empty `/storage/.homelab/{sonarr,radarr,qbittorrent}`
   trees.

## Revisiting

If the enclosure becomes too unreliable to host the whole ARR stack, point
`settings.mediaStoragePath` back at `/storage` (or a new drive) and move the data
with it. Nothing else in the config needs to change — no service references the
drives except through these two options.
