# Homelab Backup to Dropbox

Every homelab rebuild that applies a configuration (`switch`, `test`, `boot`)
first uploads an encrypted backup of the services' settings and data to the
homelab's own Dropbox App folder. `build` and `dry-build` don't. If the backup
fails, the rebuild stops before anything is applied.

- Module: `system/nixos/self-hosted-services/homelab-backup.nix` (the list of
  what is backed up), enabled by `features.homelab.backup.enable`.
- A backup is one file, `homelab-<UTC time>.tar.zst.age`, in the App folder,
  which is `Apps/<app name>/` in the main Dropbox (on the desktop:
  `~/Drives/Dropbox/Apps/<app name>/`). About 420 MB in November 2026.
- It opens with either sops age key of the user (`s1n7ax_desktop`,
  `s1n7ax_server`), so the desktop key alone is enough.
- The homelab never deletes or overwrites a backup. Delete old ones by hand in
  the Dropbox web UI or the desktop mount.

The commands below are bash (from fish, run `bash` first).

## Skip the Backup Once

For example while offline:

```shell
sudo touch /run/skip-homelab-backup
sudo nixos-rebuild switch --flake .#server
```

The rebuild removes the file, so the next one backs up again. (A reboot also
clears it. `NIXOS_NO_CHECK=1` skips it as well, together with every other
NixOS pre-switch check; inside `nixos-install` and `nixos-enter`, whose new
`/run` hides the file, it is the only way.)

## One-Time Setup: the Homelab's Dropbox Token

The token can only reach its own App folder, and only list and add files.

1. Create the app at <https://www.dropbox.com/developers/apps>: **Create app**
   → **Scoped access** → **App folder** → a name, e.g.
   `s1n7ax-homelab-backup` (it becomes the folder name under `Apps/`).
2. In the app's **Permissions** tab tick only `files.metadata.read` and
   `files.content.write`, then **Submit**. Leave everything else (sharing,
   account info, file requests) off.
3. In the **Settings** tab copy the **App key** and **App secret**.
4. Open this URL with your App key, click **Allow**, and copy the code it
   shows:

   ```
   https://www.dropbox.com/oauth2/authorize?client_id=<App key>&response_type=code&token_access_type=offline
   ```

5. Turn the code into the token rclone uses (within a few minutes; the code
   works once):

   ```shell
   curl -s https://api.dropboxapi.com/oauth2/token \
     -d grant_type=authorization_code -d code=<code> \
     -u '<App key>:<App secret>' |
     nix run nixpkgs#jq -- -c '{access_token, token_type, refresh_token, expiry: ((now | floor) + .expires_in | todate)}'
   ```

   It prints one line of JSON with a `refresh_token`. (`rclone authorize`
   would ask for more scopes than the app has.)

6. Add the three values to nix-secrets (`sops secrets.yaml` in
   github.com/s1n7ax/nix-secrets), commit and push:

   ```yaml
   rclone:
       dropbox-homelab:
           client_id: <App key>
           client_secret: <App secret>
           token: '<the JSON line from step 5>'
   ```

7. In this repo, pick up the new secrets and rebuild:

   ```shell
   nix flake update secrets
   sudo nixos-rebuild switch --flake .#server
   ```

   The rebuild logs `homelab-backup: backed up to homelab:homelab-….tar.zst.age`.

The backup reads the token straight from the incoming configuration's sops
file with the homelab's host key (`/etc/ssh/ssh_host_ed25519_key`), so a new
or rotated token is used by the very rebuild that brings it.

### Check the Token's Reach

```shell
secrets=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.secrets.outPath')/secrets.yaml
get() { sops -d --extract "[\"rclone\"][\"dropbox-homelab\"][\"$1\"]" "$secrets"; }
export RCLONE_CONFIG_HOMELAB_TYPE=dropbox
RCLONE_CONFIG_HOMELAB_CLIENT_ID=$(get client_id) RCLONE_CONFIG_HOMELAB_CLIENT_SECRET=$(get client_secret) \
RCLONE_CONFIG_HOMELAB_TOKEN=$(get token) sh -c '
  rclone lsf homelab:            # only the backups
  rclone lsf homelab:Apps        # fails: the main Dropbox is out of reach
  rclone about homelab:          # fails: no account access
'
```

## Restore

Restore onto a running homelab, or onto a new one after its first rebuild
(see below).

1. Get the backup file from the App folder (Dropbox web UI, or
   `~/Drives/Dropbox/Apps/<app name>/` on the desktop) and copy it to the
   homelab.
2. Unpack it with a sops age key (`~/.config/sops/age/keys.txt`; on a new
   homelab, a copy of the desktop's):

   ```shell
   sudo mkdir /var/tmp/restore
   age -d -i ~/.config/sops/age/keys.txt homelab-<time>.tar.zst.age |
     sudo tar --zstd -x -p --numeric-owner -C /var/tmp/restore
   ```

   `/var/tmp/restore/homelab-backup.json` lists the sources, the databases
   and the systems the backup was taken between. The rest mirrors `/`.

3. Stop the services:

   ```shell
   systemctl --user stop 'podman-*.service'
   sudo systemctl stop adguard.service dongle-m-reboot-monitor.service
   ```

4. Delete the live databases' `-wal`/`-shm` files. They belong to the old
   databases and would corrupt the restored ones:

   ```shell
   nix run nixpkgs#jq -- -r '.sources[] | .path + "/" + .databases[]' /var/tmp/restore/homelab-backup.json |
     while read -r db; do sudo rm -f "$db-wal" "$db-shm"; done
   ```

5. Copy each backed-up folder back with its owners (the containers' files
   belong to rootless podman's sub-UIDs). Only the backed-up folders are
   copied, not their parents: the backup doesn't hold the parents, so
   `~/.homelab`, `~/.homelab/sonarr` and the others keep their owner and
   mode:

   ```shell
   nix run nixpkgs#jq -- -r '.sources[].path' /var/tmp/restore/homelab-backup.json |
     while read -r dir; do
       if [ -d "/var/tmp/restore$dir" ]; then sudo cp -a "/var/tmp/restore$dir/." "$dir/"; fi
     done
   ```

6. Reboot (or start the services again), then rebuild Paperless' search
   index, which is not backed up:

   ```shell
   podman exec paperless document_index reindex
   ```

Not in a backup, because a rebuild or the services recreate them: Node-RED's
`node_modules` (`npm install` in `~/.homelab/node-red` if nodes are missing),
Home Assistant's `deps`, Piper voices, Prowlarr's indexer definitions,
Jellyfin's artwork (rescan the libraries), the Paperless search index and
auto-tagging model, and the Frigate config and z2m `configuration.yaml`
(both from this repo).

### On a New Homelab

1. Install NixOS with this repo: `sudo nixos-install --flake .#server`. The
   install takes no backup: it runs outside a booted system and none of the
   service folders exist yet, so it logs `nothing to back up yet` and goes
   on. (If the new disk already holds service data, the install tries to
   back up, and fails while the new host key can't read the token yet;
   install with `sudo NIXOS_NO_CHECK=1 nixos-install --flake .#server`
   then.)
2. Boot it. The new machine has a new SSH host key: add its age key
   (`nix run nixpkgs#ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`) to
   nix-secrets' `.sops.yaml` as `server`, run `sops updatekeys secrets.yaml`
   on the desktop, push, and `nix flake update secrets` here.
3. Skip the backup on the first rebuild (the services hold nothing worth
   keeping yet): `sudo touch /run/skip-homelab-backup`, then
   `sudo nixos-rebuild switch --flake .#server`.
4. Copy the desktop's `~/.config/sops/age/keys.txt` to the same path on the
   homelab, and restore as above.
