# homelab-backup: upload an encrypted backup of the homelab services'
# settings and data to the homelab's Dropbox App folder. The NixOS pre-switch
# check runs it before every rebuild that applies a configuration:
#
#   homelab-backup pre-switch <incoming system> <action>
#
# `switch`, `test` and `boot` back up; every other action (`dry-activate`,
# `check`) does nothing. Any failure exits non-zero, which stops the rebuild
# before the new configuration is applied.
#
# Steps: decrypt the Dropbox token from sops and list the App folder (fails
# fast when offline or the token is bad), snapshot each SQLite database with
# VACUUM INTO, tar the sources with the snapshots in place of the live
# databases, compress (zstd), encrypt (age), upload as a new
# homelab-<UTC timestamp>.tar.zst.age. Nothing on Dropbox is ever deleted or
# overwritten.
#
# Skip once: create the skip file (`sudo touch /run/skip-homelab-backup`); it
# is removed when honoured.
#
# Outside a booted system (nixos-install, nixos-enter: the new system runs in
# a chroot where systemd never started), nothing is backed up when none of
# the sources exist: a freshly installed homelab has nothing to back up yet.
# On the booted homelab, or in a chroot of a homelab that has service data,
# the backup is taken as always.
#
# Environment (set by the NixOS module; the flake check points it at a test
# tree):
#   HOMELAB_BACKUP_SPEC           JSON {"sources": [{name, path, databases, exclude}]}:
#                                 databases and exclude are relative to path,
#                                 exclude entries are globs (`*` matches `/`)
#   HOMELAB_BACKUP_RECIPIENTS     age recipients, one per line
#   HOMELAB_BACKUP_REMOTE         rclone remote to upload to, e.g. homelab:
#   HOMELAB_BACKUP_SKIP_FILE      skip marker
#   HOMELAB_BACKUP_BOOTED_MARKER  exists only on a system booted with systemd
#                                 (/run/systemd/system, as sd_booted checks)
#   HOMELAB_BACKUP_TMPDIR         where the archive is built (needs room for it
#                                 and the database snapshots)
#   HOMELAB_BACKUP_SOPS_FILE      sops file holding the Dropbox app and token
#   HOMELAB_BACKUP_SOPS_KEY       sops key of the map with client_id,
#                                 client_secret and token, e.g. rclone/dropbox-homelab
#   HOMELAB_BACKUP_SSH_KEYS       SSH keys sops-nix decrypts with (converted
#                                 with ssh-to-age), one per line
#   HOMELAB_BACKUP_AGE_KEY_FILE   age key file sops-nix decrypts with (optional)
#   HOMELAB_BACKUP_RCLONE_CONFIG  use this rclone config instead of the sops
#                                 token (tests)
#   HOMELAB_BACKUP_TIMESTAMP      timestamp in the backup's name (default: now, UTC)

log() {
  printf 'homelab-backup: %s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

usage() {
  echo "usage: homelab-backup pre-switch <incoming system> <action>" >&2
  exit 2
}

[ "${1:-}" = pre-switch ] || usage
incoming=${2:-}
action=${3:-}
{ [ -n "$incoming" ] && [ -n "$action" ]; } || usage

spec=${HOMELAB_BACKUP_SPEC:?}
remote=${HOMELAB_BACKUP_REMOTE:?}
skip_file=${HOMELAB_BACKUP_SKIP_FILE:?}
booted_marker=${HOMELAB_BACKUP_BOOTED_MARKER:?}
tmp_root=${HOMELAB_BACKUP_TMPDIR:?}

case $action in
  switch | test | boot) ;;
  *)
    log "not backing up (action: $action)"
    exit 0
    ;;
esac

if [ -e "$skip_file" ]; then
  rm -f -- "$skip_file"
  log "SKIPPED on request: $skip_file was present (now removed). No backup was taken before this $action."
  exit 0
fi

recipient_args=()
while IFS= read -r recipient; do
  [ -n "$recipient" ] && recipient_args+=(-r "$recipient")
done <<<"${HOMELAB_BACKUP_RECIPIENTS:-}"
[ "${#recipient_args[@]}" -gt 0 ] || die "HOMELAB_BACKUP_RECIPIENTS lists no age recipient"
jq -e '.sources | type == "array"' "$spec" >/dev/null || die "$spec is not a backup spec"

any_source_exists() {
  local path
  while IFS= read -r path; do
    [ ! -d "$path" ] || return 0
  done < <(jq -r '.sources[].path' "$spec")
  return 1
}

if [ ! -d "$booted_marker" ] && ! any_source_exists; then
  log "not backing up: not a booted system (no $booted_marker, e.g. nixos-install) and none of the sources exist, so there is nothing to back up yet"
  exit 0
fi

work=
on_exit() {
  local status=$?
  [ -z "$work" ] || rm -rf -- "$work"
  if [ "$status" -ne 0 ]; then
    log "backup FAILED, so the new configuration was NOT applied."
    log "To rebuild without a backup (e.g. while offline): sudo touch $skip_file, then rebuild again."
    if [ ! -d "$booted_marker" ]; then
      log "nixos-install and nixos-enter hide $skip_file (their /run is a new tmpfs): set NIXOS_NO_CHECK=1 instead, which skips every pre-switch check."
    fi
  fi
  exit "$status"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

umask 077
mkdir -p -- "$tmp_root"
work=$(mktemp -d "$tmp_root/homelab-backup.XXXXXXXXXX")
# sops and rclone look under $HOME for keys and caches; the pre-switch check
# runs without one.
export HOME=$work
stage=$work/stage
mkdir -p "$stage"
: >"$work/missing"

timestamp=${HOMELAB_BACKUP_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
name="homelab-$timestamp.tar.zst.age"
# rclone resolves `remote:/path` against the account root (and then needs
# the account_info.read scope); `remote:path` stays inside the App folder.
case $remote in
  *:) target=$remote$name ;;
  *) target=${remote%/}/$name ;;
esac

rclone_config=${HOMELAB_BACKUP_RCLONE_CONFIG:-$work/rclone.conf}

rclone_() {
  rclone --config "$rclone_config" --cache-dir "$work/rclone-cache" \
    --contimeout 15s --timeout 2m "$@"
}

# Writes the rclone config of the `homelab` remote from the sops secrets,
# decrypted with the same keys sops-nix uses (the host's SSH key). Read here
# rather than from /run/secrets: sops-nix installs secrets during activation,
# after this check, so a new or rotated token would not be there yet.
write_rclone_config() {
  local sops_file=${HOMELAB_BACKUP_SOPS_FILE:?} key=${HOMELAB_BACKUP_SOPS_KEY:?}
  local identities="" ssh_key identity field value

  while IFS= read -r ssh_key; do
    { [ -n "$ssh_key" ] && [ -r "$ssh_key" ]; } || continue
    identity=$(ssh-to-age -private-key -i "$ssh_key") ||
      die "cannot convert $ssh_key into an age key"
    identities+=$identity$'\n'
  done <<<"${HOMELAB_BACKUP_SSH_KEYS:-}"
  if [ -n "${HOMELAB_BACKUP_AGE_KEY_FILE:-}" ] && [ -r "$HOMELAB_BACKUP_AGE_KEY_FILE" ]; then
    identities+=$(<"$HOMELAB_BACKUP_AGE_KEY_FILE")$'\n'
  fi
  [ -n "$identities" ] ||
    die "no key to decrypt $sops_file with (looked for: ${HOMELAB_BACKUP_SSH_KEYS:-} ${HOMELAB_BACKUP_AGE_KEY_FILE:-})"

  {
    echo "[homelab]"
    echo "type = dropbox"
    for field in client_id client_secret token; do
      value=$(SOPS_AGE_KEY=$identities sops --decrypt \
        --extract "[\"${key//\//\"][\"}\"][\"$field\"]" "$sops_file") ||
        die "cannot read the sops secret $key/$field from $sops_file; doc/homelab-backup.md says how to create it"
      printf '%s = %s\n' "$field" "$value"
    done
  } >"$rclone_config"
}

# Snapshots a live SQLite database into the stage tree at the same path, with
# the original's owner, mode and mtime. VACUUM INTO reads one consistent
# snapshot (WAL contents included) without blocking the service's writes.
# Running as root is safe: SQLite gives any -wal/-shm it creates the
# database's owner.
snapshot() {
  local db=$1 dest=$stage$1 check
  case $dest in
    *\'*) die "cannot snapshot $db: the path contains a quote" ;;
  esac
  mkdir -p -- "$(dirname -- "$dest")"
  nice -n 10 sqlite3 -bail -batch "$db" ".timeout 60000" "VACUUM INTO '$dest'" </dev/null >/dev/null ||
    die "cannot snapshot the database $db"
  check=$(sqlite3 -bail -batch "$dest" "PRAGMA quick_check" </dev/null) ||
    die "cannot check the snapshot of $db"
  [ "$check" = ok ] || die "the snapshot of $db failed its integrity check: $check"
  chown --reference="$db" -- "$dest"
  chmod --reference="$db" -- "$dest"
  touch --reference="$db" -- "$dest"
}

start=$SECONDS

if [ -z "${HOMELAB_BACKUP_RCLONE_CONFIG:-}" ]; then
  write_rclone_config
fi

log "checking the Dropbox App folder ($remote)"
listing=$(rclone_ lsf --files-only --max-depth 1 --retries 1 --low-level-retries 1 "$remote") ||
  die "cannot list the homelab's Dropbox App folder: offline, Dropbox unreachable, or the token in sops (${HOMELAB_BACKUP_SOPS_KEY:-the rclone config}) is invalid or revoked"
if grep -qxF -- "$name" <<<"$listing"; then
  die "$target already exists; the homelab never overwrites a backup"
fi

# Sources and their excludes. tar matches the excludes against member names,
# which are the paths without their leading `/` (tar runs in /).
paths=()
excludes=()
snapshots=()
while IFS= read -r source; do
  path=$(jq -r .path <<<"$source")
  rel=${path#/}
  if [ ! -d "$path" ]; then
    log "warning: $path is missing; not backing it up"
    echo "$path" >>"$work/missing"
    continue
  fi
  paths+=("$rel")

  while IFS= read -r pattern; do
    excludes+=("--exclude=$rel/$pattern")
  done < <(jq -r '.exclude[]' <<<"$source")

  while IFS= read -r db; do
    # The live database and its journal files never go in; the snapshot does.
    for suffix in "" -wal -shm -journal; do
      excludes+=("--exclude=$rel/$db$suffix")
    done
    if [ -f "$path/$db" ]; then
      log "snapshotting $path/$db"
      snapshot "$path/$db"
      snapshots+=("${stage#/}/$rel/$db")
    else
      log "warning: database $path/$db is missing; not backing it up"
      echo "$path/$db" >>"$work/missing"
    fi
  done < <(jq -r '.databases[]' <<<"$source")
done < <(jq -c '.sources[]' "$spec")

[ "${#paths[@]}" -gt 0 ] || die "none of the sources in $spec exist"

jq -n \
  --arg created "$timestamp" \
  --arg host "$(uname -n)" \
  --arg action "$action" \
  --arg current "$(readlink -f /run/current-system || true)" \
  --arg incoming "$incoming" \
  --rawfile missing "$work/missing" \
  --slurpfile spec "$spec" \
  '{
    created: $created,
    host: $host,
    action: $action,
    current_system: $current,
    incoming_system: $incoming,
    missing: ($missing | split("\n") | map(select(. != ""))),
    sources: $spec[0].sources
  }' >"$stage/homelab-backup.json"

# Stage entries (snapshots, manifest) are stored at their final names.
prefix=${stage#/}/
prefix=${prefix//./\\.}

log "archiving ${#paths[@]} sources and ${#snapshots[@]} database snapshots"
archive=$work/$name
set +e
nice -n 10 tar --create --file=- --directory=/ \
  --numeric-owner --one-file-system \
  --warning=no-file-changed --warning=no-file-removed --warning=no-file-ignored \
  --anchored --wildcards "${excludes[@]}" \
  --transform="s,^$prefix,,rSH" \
  -- "${paths[@]}" "${snapshots[@]}" "${stage#/}/homelab-backup.json" |
  nice -n 10 zstd -q -T0 |
  age "${recipient_args[@]}" >"$archive"
statuses=("${PIPESTATUS[@]}")
set -e
# tar exits 1 when a file changed or vanished while it was read: config files
# are replaced atomically by the services, and databases come from snapshots.
[ "${statuses[0]}" -le 1 ] || die "tar failed (exit ${statuses[0]})"
[ "${statuses[1]}" -eq 0 ] || die "zstd failed (exit ${statuses[1]})"
[ "${statuses[2]}" -eq 0 ] || die "age failed (exit ${statuses[2]})"

size=$(du -h -- "$archive" | cut -f1)
log "uploading $name ($size)"
rclone_ copyto --immutable --retries 3 --low-level-retries 10 \
  --stats 30s --stats-one-line --stats-log-level NOTICE \
  "$archive" "$target" ||
  die "uploading $target failed"

log "backed up to $target ($size, $((SECONDS - start))s)"
