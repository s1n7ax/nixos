# homelab-restore: put a backup made by homelab-backup back in place, on the
# homelab it came from or on a new one. Stop the services first
# (doc/homelab-backup.md, "Restore"):
#
#   sudo homelab-restore -i <age key file> <homelab-<time>.tar.zst.age>
#
# Steps: decrypt the backup with the age key and unpack it, with its owners
# and modes, into a temporary folder. Then, for each folder its manifest
# (homelab-backup.json) lists and the backup holds:
#   - create the folder's missing parents with the owner and mode they had
#     on the backed-up homelab (the manifest records them); parents that
#     exist, such as ~/.homelab, are left as they are
#   - delete the live databases' -wal, -shm and -journal files: they belong
#     to the old databases and would corrupt the restored ones
#   - copy the folder back over the live one (cp -a: owners, modes, times)
# Any failure stops it with an error and a non-zero exit. The temporary
# folder is removed at the end.
#
# Environment:
#   HOMELAB_RESTORE_TMPDIR  where the backup is unpacked (default: /var/tmp;
#                           needs room for the unpacked backup)

log() {
  printf 'homelab-restore: %s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

usage() {
  echo "usage: sudo homelab-restore -i <age key file> <backup file>" >&2
  exit 2
}

identity=
while getopts i: opt; do
  case $opt in
    i) identity=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
{ [ "$#" -eq 1 ] && [ -n "$identity" ]; } || usage
backup=$1

[ "$(id -u)" -eq 0 ] ||
  die "run it as root (sudo homelab-restore ...): only root can give the restored files their owners"
[ -r "$identity" ] || die "cannot read the age key $identity"
[ -r "$backup" ] || die "cannot read the backup $backup"

tmp_root=${HOMELAB_RESTORE_TMPDIR:-/var/tmp}

work=
restored=()
on_exit() {
  local status=$?
  [ -z "$work" ] || rm -rf -- "$work"
  if [ "$status" -ne 0 ]; then
    if [ "${#restored[@]}" -gt 0 ]; then
      log "restore FAILED after restoring: ${restored[*]}"
    else
      log "restore FAILED; nothing was restored"
    fi
  fi
  exit "$status"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

umask 077
mkdir -p -- "$tmp_root"
work=$(mktemp -d "$tmp_root/homelab-restore.XXXXXXXXXX")
tree=$work/backup
mkdir -- "$tree"

log "unpacking $backup"
set +e
age -d -i "$identity" "$backup" |
  tar --zstd -x -f - -C "$tree" --same-owner --same-permissions --numeric-owner
statuses=("${PIPESTATUS[@]}")
set -e
[ "${statuses[0]}" -eq 0 ] ||
  die "cannot decrypt $backup with $identity (age exit ${statuses[0]}): a key that is not a recipient, or not a homelab backup"
[ "${statuses[1]}" -eq 0 ] || die "cannot unpack $backup (tar exit ${statuses[1]})"

manifest=$tree/homelab-backup.json
[ -f "$manifest" ] || die "$backup holds no homelab-backup.json: not a homelab backup"
jq -e '.sources | type == "array" and length > 0' "$manifest" >/dev/null ||
  die "cannot read the list of backed-up folders from the backup's homelab-backup.json"
sources=$(jq -c '.sources[]' "$manifest") ||
  die "cannot read the list of backed-up folders from the backup's homelab-backup.json"

# Creates the missing folders above $1, top down, with the owner and mode the
# manifest records for them.
make_parents() {
  local path=$1 dir entry uid gid mode
  local parents=()
  dir=$(dirname -- "$path")
  while [ "$dir" != / ]; do
    parents=("$dir" "${parents[@]}")
    dir=$(dirname -- "$dir")
  done
  for dir in "${parents[@]}"; do
    [ ! -d "$dir" ] || continue
    { [ ! -e "$dir" ] && [ ! -L "$dir" ]; } ||
      die "cannot restore $path: $dir exists but is not a folder"
    entry=$(jq -r --arg dir "$dir" \
      '.parents[$dir] // empty | "\(.uid) \(.gid) \(.mode)"' "$manifest") ||
      die "cannot read the owner and mode of $dir from the backup's homelab-backup.json"
    [ -n "$entry" ] ||
      die "cannot restore $path: $dir is missing, and the backup does not record its owner and mode"
    read -r uid gid mode <<<"$entry"
    mkdir -- "$dir"
    chown -- "$uid:$gid" "$dir"
    chmod -- "$mode" "$dir"
    log "created $dir (owner $uid:$gid, mode $mode)"
  done
}

total=0
while IFS= read -r source; do
  total=$((total + 1))
  path=$(jq -r .path <<<"$source")
  case $path in
    /*) ;;
    *) die "the backup lists a folder that is not an absolute path: $path" ;;
  esac
  [ "$(realpath -m -s -- "$path")" = "$path" ] ||
    die "the backup lists a folder whose path is not normalized: $path"
  if [ ! -d "$tree$path" ]; then
    log "warning: the backup does not hold $path (it was missing when the backup was taken); leaving it as it is"
    continue
  fi

  make_parents "$path"

  databases=$(jq -r '(.databases // [])[]' <<<"$source") ||
    die "cannot read the databases of $path from the backup's homelab-backup.json"
  while IFS= read -r db; do
    [ -n "$db" ] || continue
    if [ -f "$tree$path/$db" ]; then
      rm -f -- "$path/$db-wal" "$path/$db-shm" "$path/$db-journal"
    else
      log "warning: the backup does not hold the database $path/$db; leaving the live one as it is"
    fi
  done <<<"$databases"

  cp -a -- "$tree$path/." "$path/" || die "cannot copy $path back"
  log "restored $path"
  restored+=("$path")
done <<<"$sources"

[ "${#restored[@]}" -gt 0 ] || die "the backup holds none of the folders it lists"
log "restored ${#restored[@]} of $total folders from $backup; start the services again (or reboot)"
