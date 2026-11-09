# Tests homelab-backup against fake service data, a local rclone remote in
# place of Dropbox and throwaway age keys. Run by the flake check
# `homelab-backup` (in the Nix sandbox, which has no network).
set -euo pipefail

t=$(mktemp -d)
export HOME=$t/home
mkdir -p "$HOME"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}
pass() {
  echo "ok: $*"
}

# --- Fake service data ------------------------------------------------------

svc=$t/data/svc
mkdir -p "$svc/logs" "$svc/MediaCover" "$svc/keep/deep"
echo setting >"$svc/config.xml"
echo log >"$svc/logs/app.txt"
echo poster >"$svc/MediaCover/poster.jpg"
echo 123 >"$svc/app.pid"
echo 123 >"$svc/keep/deep/other.pid"
echo nested >"$svc/keep/deep/nested.txt"

# A source two folders below the shared parent, like /opt/adguard/conf; each
# folder above it has its own mode (all keep u=rwx: fakeroot adds it anyway).
conf=$t/data/opt/adguard/conf
mkdir -p "$conf"
echo 'dns: {}' >"$conf/AdGuardHome.yaml"
chmod 0751 "$t/data"
chmod 0711 "$t/data/opt"
chmod 0755 "$t/data/opt/adguard"
chmod 0700 "$conf"

# A WAL database whose committed rows are still only in the -wal file, held
# open by a "service" with an uncommitted write, next to a unix socket.
python3 - "$svc" <<'EOF'
import socket, sqlite3, sys
d = sys.argv[1]
c = sqlite3.connect(f"{d}/app.db", isolation_level=None)
c.execute("PRAGMA journal_mode=WAL")
c.execute("CREATE TABLE t(x)")
c.execute("INSERT INTO t VALUES ('one'), ('two')")
c.close()
socket.socket(socket.AF_UNIX).bind(f"{d}/ipc-socket")
EOF
python3 - "$svc/app.db" "$t/holder-ready" <<'EOF' &
import pathlib, sqlite3, sys, time
c = sqlite3.connect(sys.argv[1], isolation_level=None)
c.execute("PRAGMA wal_autocheckpoint=0")
c.execute("INSERT INTO t VALUES ('three')")
c.execute("BEGIN IMMEDIATE")
c.execute("INSERT INTO t VALUES ('uncommitted')")
pathlib.Path(sys.argv[2]).touch()
time.sleep(600)
EOF
holder=$!
trap 'kill "$holder" 2>/dev/null || true' EXIT
for _ in $(seq 100); do
  [ -e "$t/holder-ready" ] && break
  sleep 0.1
done
[ -e "$t/holder-ready" ] || fail "the database holder did not start"
[ -s "$svc/app.db-wal" ] || fail "the test database has no WAL content"

cat >"$t/spec.json" <<EOF
{
  "sources": [
    {
      "name": "svc",
      "path": "$svc",
      "databases": ["app.db", "absent.db"],
      "exclude": ["logs", "MediaCover", "*.pid"]
    },
    { "name": "conf", "path": "$conf", "databases": [], "exclude": [] },
    { "name": "gone", "path": "$t/data/gone", "databases": [], "exclude": [] }
  ]
}
EOF

age-keygen -o "$t/desktop.key" 2>/dev/null
age-keygen -o "$t/server.key" 2>/dev/null

mkdir -p "$t/remote"
printf '[homelab]\ntype = local\n' >"$t/rclone.conf"

export HOMELAB_BACKUP_SPEC=$t/spec.json
HOMELAB_BACKUP_RECIPIENTS="$(age-keygen -y "$t/desktop.key")
$(age-keygen -y "$t/server.key")"
export HOMELAB_BACKUP_RECIPIENTS
export HOMELAB_BACKUP_REMOTE=homelab:$t/remote
export HOMELAB_BACKUP_RCLONE_CONFIG=$t/rclone.conf
export HOMELAB_BACKUP_SKIP_FILE=$t/skip
mkdir "$t/booted"
export HOMELAB_BACKUP_BOOTED_MARKER=$t/booted
export HOMELAB_BACKUP_TMPDIR=$t/tmp

backups() {
  find "$t/remote" -type f -printf '%f\n' | sort
}

first=homelab-20260101T000000Z.tar.zst.age
second=homelab-20260101T000001Z.tar.zst.age

# --- A switch uploads one backup --------------------------------------------

HOMELAB_BACKUP_TIMESTAMP=20260101T000000Z homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"
cat "$t/log"
[ "$(backups)" = "$first" ] || fail "expected only $first, got: $(backups)"
grep -q "warning: database $svc/absent.db is missing" "$t/log" || fail "no warning for the missing database"
grep -q "warning: $t/data/gone is missing" "$t/log" || fail "no warning for the missing source"
[ -z "$(ls -A "$t/tmp")" ] || fail "the work directory was left behind: $(ls -A "$t/tmp")"
pass "switch uploads one backup and cleans up"

# --- It opens with one recipient's key alone --------------------------------

age -d -i "$t/desktop.key" "$t/remote/$first" | tar --zstd -t >"$t/list"
rel=${svc#/}
for want in "$rel" "$rel/config.xml" "$rel/keep/deep/nested.txt" "$rel/app.db" "${conf#/}/AdGuardHome.yaml" homelab-backup.json; do
  grep -qxF "$want" "$t/list" || grep -qxF "$want/" "$t/list" || fail "$want is not in the backup"
done
for unwanted in logs MediaCover app.pid keep/deep/other.pid app.db-wal app.db-shm ipc-socket; do
  if grep -q "^$rel/$unwanted" "$t/list"; then
    fail "$unwanted is in the backup"
  fi
done
if grep -q "stage" "$t/list"; then
  fail "staging paths leaked into the backup"
fi
pass "the backup holds the settings and the snapshot, not the excluded files"

mkdir "$t/restore"
age -d -i "$t/desktop.key" "$t/remote/$first" | tar --zstd -x -C "$t/restore"
db=$t/restore/$rel/app.db
[ "$(sqlite3 "$db" 'PRAGMA quick_check')" = ok ] || fail "the restored database is damaged"
rows=$(sqlite3 "$db" 'SELECT group_concat(x) FROM (SELECT x FROM t ORDER BY rowid)')
[ "$rows" = one,two,three ] || fail "the restored database has rows '$rows', expected one,two,three"
[ "$(cat "$t/restore/$rel/config.xml")" = setting ] || fail "config.xml was not restored"
jq -e --arg missing "$svc/absent.db" --arg data "$t/data" --argjson uid "$(id -u)" '
  .action == "switch"
  and .incoming_system == "/nix/store/new-system"
  and .created == "20260101T000000Z"
  and (.missing | index($missing) != null)
  and (.sources | length == 3)
  and .parents[$data].uid == $uid
  and .parents[$data].mode == "751"
  and .parents[$data + "/opt"].mode == "711"
  and .parents[$data + "/opt/adguard"].mode == "755"
  and (.parents | has($data + "/opt/adguard/conf") | not)
  and (.parents | has("/") | not)
' "$t/restore/homelab-backup.json" >/dev/null || fail "the manifest is wrong: $(cat "$t/restore/homelab-backup.json")"
pass "the snapshot opens with the committed rows only, and the manifest is right"

# --- A second rebuild adds a second backup; the first stays unchanged ------

sum=$(sha256sum "$t/remote/$first")
HOMELAB_BACKUP_TIMESTAMP=20260101T000001Z homelab-backup pre-switch /nix/store/new-system boot 2>/dev/null
[ "$(backups)" = "$first
$second" ] || fail "expected two backups, got: $(backups)"
[ "$(sha256sum "$t/remote/$first")" = "$sum" ] || fail "the first backup changed"
pass "a second rebuild leaves two backups and the first unchanged"

# --- It never overwrites ----------------------------------------------------

if HOMELAB_BACKUP_TIMESTAMP=20260101T000000Z homelab-backup pre-switch /nix/store/new-system test 2>"$t/log"; then
  fail "a backup with an existing name succeeded"
fi
grep -q "already exists" "$t/log" || fail "no 'already exists' message: $(cat "$t/log")"
grep -q "NOT applied" "$t/log" || fail "no 'NOT applied' message"
[ "$(sha256sum "$t/remote/$first")" = "$sum" ] || fail "the first backup was overwritten"
pass "an existing name fails instead of overwriting"

# --- Actions that apply nothing don't back up ------------------------------

for action in dry-activate check; do
  homelab-backup pre-switch /nix/store/new-system "$action" 2>/dev/null
  [ "$(backups | wc -l)" -eq 2 ] || fail "$action took a backup"
done
pass "dry-activate and check take no backup"

# --- The skip file skips once ----------------------------------------------

touch "$t/skip"
homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"
grep -q SKIPPED "$t/log" || fail "no SKIPPED message"
[ ! -e "$t/skip" ] || fail "the skip file was not removed"
[ "$(backups | wc -l)" -eq 2 ] || fail "a skipped rebuild took a backup"
pass "the skip file skips one backup and is removed"

# --- Dropbox via the sops token: unreachable, missing secret, no key -------

unset HOMELAB_BACKUP_RCLONE_CONFIG
export HOMELAB_BACKUP_REMOTE=homelab:
ssh-keygen -q -t ed25519 -N "" -C test -f "$t/ssh_host_ed25519_key"
host_recipient=$(ssh-to-age -i "$t/ssh_host_ed25519_key.pub")
cat >"$t/secrets.yaml" <<'EOF'
rclone:
    dropbox-homelab:
        client_id: test-client-id-4b1f
        client_secret: test-client-secret-9e2c
        token: '{"access_token":"test-access-7d3a","token_type":"bearer","refresh_token":"test-refresh-5c8e","expiry":"2000-01-01T00:00:00Z"}'
EOF
sops encrypt --age "$host_recipient" --input-type yaml --output-type yaml "$t/secrets.yaml" >"$t/secrets.enc.yaml"
export HOMELAB_BACKUP_SOPS_FILE=$t/secrets.enc.yaml
export HOMELAB_BACKUP_SOPS_KEY=rclone/dropbox-homelab
export HOMELAB_BACKUP_SSH_KEYS=$t/ssh_host_ed25519_key
export HOMELAB_BACKUP_AGE_KEY_FILE=$t/absent-key.txt

if homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"; then
  fail "a backup without network succeeded"
fi
cat "$t/log"
grep -q "cannot list the homelab's Dropbox App folder" "$t/log" || fail "no 'cannot list' message"
grep -q "sudo touch $t/skip" "$t/log" || fail "no skip hint"
if grep -q NIXOS_NO_CHECK "$t/log"; then
  fail "a booted system got the nixos-install hint"
fi
if grep -E "test-(client-secret|access|refresh)" "$t/log"; then
  fail "a secret leaked into the output"
fi
[ -z "$(ls -A "$t/tmp")" ] || fail "the work directory (with the token) was left behind"
pass "an unreachable Dropbox fails with a clear message, the skip hint and no leaked secret"

# --- nixos-install: no booted system, no service data ----------------------

# nixos-install runs `switch-to-configuration boot` in a chroot of the new
# system: systemd never started there, the host key is not a sops recipient
# yet and none of the service folders exist.
cat >"$t/new-homelab-spec.json" <<EOF
{
  "sources": [
    { "name": "svc", "path": "$t/data/new/svc", "databases": ["app.db"], "exclude": [] },
    { "name": "gone", "path": "$t/data/gone", "databases": [], "exclude": [] }
  ]
}
EOF
HOMELAB_BACKUP_SPEC=$t/new-homelab-spec.json HOMELAB_BACKUP_BOOTED_MARKER=$t/not-booted \
  HOMELAB_BACKUP_SSH_KEYS=$t/absent-ssh-key \
  homelab-backup pre-switch /nix/store/new-system boot 2>"$t/log" ||
  fail "nixos-install of a new homelab failed: $(cat "$t/log")"
grep -q "nothing to back up yet" "$t/log" || fail "no 'nothing to back up yet' message: $(cat "$t/log")"
pass "nixos-install of a new homelab backs up nothing and does not fail"

if HOMELAB_BACKUP_SPEC=$t/new-homelab-spec.json \
  HOMELAB_BACKUP_RCLONE_CONFIG=$t/rclone.conf HOMELAB_BACKUP_REMOTE=homelab:$t/remote \
  homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"; then
  fail "a booted homelab without any service data rebuilt without a backup"
fi
grep -q "none of the sources in $t/new-homelab-spec.json exist" "$t/log" || fail "no 'none of the sources' message: $(cat "$t/log")"
grep -q "NOT applied" "$t/log" || fail "no 'NOT applied' message"
pass "a booted homelab without any service data still fails instead of skipping"

if HOMELAB_BACKUP_BOOTED_MARKER=$t/not-booted homelab-backup pre-switch /nix/store/new-system boot 2>"$t/log"; then
  fail "a chroot of a homelab with service data rebuilt without a backup"
fi
grep -q "cannot list the homelab's Dropbox App folder" "$t/log" || fail "the chroot did not try to back up: $(cat "$t/log")"
grep -q "set NIXOS_NO_CHECK=1 instead" "$t/log" || fail "no NIXOS_NO_CHECK hint in the chroot: $(cat "$t/log")"
pass "a chroot of a homelab with service data still backs up, and says how to skip there"

if HOMELAB_BACKUP_SOPS_KEY=rclone/dropbox-other homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"; then
  fail "a backup without the token secret succeeded"
fi
grep -q "cannot read the sops secret rclone/dropbox-other/client_id" "$t/log" || fail "no 'cannot read the sops secret' message: $(cat "$t/log")"
pass "a missing token secret fails with its sops key"

if HOMELAB_BACKUP_SSH_KEYS=$t/absent-ssh-key homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"; then
  fail "a backup without a decryption key succeeded"
fi
grep -q "no key to decrypt" "$t/log" || fail "no 'no key to decrypt' message: $(cat "$t/log")"
pass "a missing host key fails with a clear message"

if HOMELAB_BACKUP_SPEC=$t/absent-spec.json homelab-backup pre-switch /nix/store/new-system switch 2>"$t/log"; then
  fail "a backup without a spec succeeded"
fi
grep -q "is not a backup spec" "$t/log" || fail "no 'is not a backup spec' message: $(cat "$t/log")"
pass "a missing spec fails with a clear message"

[ "$(backups | wc -l)" -eq 2 ] || fail "a failed run left a backup"

# --- Restore ----------------------------------------------------------------

# The service stops; its -wal/-shm stay behind, as after a crash.
kill "$holder"
wait "$holder" 2>/dev/null || true
[ -e "$svc/app.db-wal" ] || fail "the stopped service left no -wal behind"

export HOMELAB_RESTORE_TMPDIR=$t/restore-tmp
# homelab-restore needs root to give the files their owners; fakeroot stands
# in for sudo.
restore() {
  fakeroot homelab-restore -i "$t/desktop.key" "$@"
}
rows() {
  sqlite3 "$svc/app.db" 'SELECT group_concat(x) FROM (SELECT x FROM t ORDER BY rowid)'
}

if homelab-restore -i "$t/desktop.key" "$t/remote/$first" 2>"$t/log"; then
  fail "a restore without root succeeded"
fi
grep -q "run it as root" "$t/log" || fail "no 'run it as root' message: $(cat "$t/log")"
pass "a restore without root fails and says to use sudo"

# Onto the homelab the backup came from.
echo changed >"$svc/config.xml"
chmod 0700 "$t/data"
restore "$t/remote/$first" 2>"$t/log" || fail "the restore failed: $(cat "$t/log")"
cat "$t/log"
[ "$(cat "$svc/config.xml")" = setting ] || fail "config.xml was not restored"
for journal in app.db-wal app.db-shm; do
  [ ! -e "$svc/$journal" ] || fail "the live $journal was left next to the restored database"
done
[ "$(rows)" = one,two,three ] || fail "the restored database has rows '$(rows)', expected one,two,three"
[ "$(stat -c %a "$t/data")" = 700 ] || fail "the restore changed the mode of an existing parent to $(stat -c %a "$t/data")"
[ -z "$(ls -A "$t/restore-tmp")" ] || fail "the restore left its work folder behind"
pass "a restore brings back settings and databases, drops the live -wal/-shm and leaves existing parents alone"

# Onto a new homelab: none of the folders exist.
rm -rf "$t/data"
restore "$t/remote/$first" 2>"$t/log" || fail "the restore onto a new homelab failed: $(cat "$t/log")"
cat "$t/log"
[ "$(cat "$svc/config.xml")" = setting ] || fail "config.xml was not restored onto a new homelab"
[ "$(cat "$svc/keep/deep/nested.txt")" = nested ] || fail "keep/deep/nested.txt was not restored onto a new homelab"
[ "$(cat "$conf/AdGuardHome.yaml")" = 'dns: {}' ] || fail "the source below missing parents was not restored"
[ "$(rows)" = one,two,three ] || fail "the database restored onto a new homelab has rows '$(rows)'"
for want in "$t/data 751" "$t/data/opt 711" "$t/data/opt/adguard 755" "$conf 700"; do
  read -r dir mode <<<"$want"
  [ "$(stat -c %a "$dir")" = "$mode" ] || fail "$dir has mode $(stat -c %a "$dir"), expected $mode"
done
[ ! -e "$t/data/gone" ] || fail "the restore created a folder the backup does not hold"
grep -q "warning: the backup does not hold $t/data/gone" "$t/log" || fail "no warning for the folder the backup does not hold"
pass "a restore onto a new homelab creates the missing parents with their recorded owner and mode"

# Backups it cannot read fail loudly and restore nothing.
echo changed >"$svc/config.xml"
age-keygen -o "$t/other.key" 2>/dev/null
if fakeroot homelab-restore -i "$t/other.key" "$t/remote/$first" 2>"$t/log"; then
  fail "a restore with a key that is not a recipient succeeded"
fi
grep -q "cannot decrypt" "$t/log" || fail "no 'cannot decrypt' message: $(cat "$t/log")"
grep -q "nothing was restored" "$t/log" || fail "no 'nothing was restored' message: $(cat "$t/log")"

bad_backup() {
  local dir=$t/bad-$1
  mkdir -p "$dir/$rel"
  echo bad >"$dir/$rel/config.xml"
  if [ -n "$2" ]; then
    printf '%s' "$2" >"$dir/homelab-backup.json"
  fi
  tar --zstd -c -C "$dir" . | age -r "$(age-keygen -y "$t/desktop.key")" >"$dir.tar.zst.age"
}
bad_backup none ""
bad_backup broken '{"sources": ['
bad_backup empty '{"sources": []}'
for bad in none:"holds no homelab-backup.json" broken:"cannot read the list" empty:"cannot read the list"; do
  if restore "$t/bad-${bad%%:*}.tar.zst.age" 2>"$t/log"; then
    fail "a restore of a backup with manifest '${bad%%:*}' succeeded"
  fi
  grep -q "${bad#*:}" "$t/log" || fail "no '${bad#*:}' message for manifest '${bad%%:*}': $(cat "$t/log")"
  grep -q "nothing was restored" "$t/log" || fail "no 'nothing was restored' message: $(cat "$t/log")"
done
[ "$(cat "$svc/config.xml")" = changed ] || fail "a failed restore changed config.xml"
[ -z "$(ls -A "$t/restore-tmp")" ] || fail "a failed restore left its work folder behind"
pass "a backup without a readable manifest, or with the wrong key, fails loudly and restores nothing"
