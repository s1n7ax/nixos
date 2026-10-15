# power-watch: tells `power-profile` which games are running. Runs as the
# power-watch user unit for the whole graphical session:
#
#   power-watch [run]  poll every 2 s (default)
#   power-watch stop   ExecStopPost: clear the games file and sync
#
# A game is a Steam launch (native, Proton or a non-Steam shortcut: each runs
# under `reaper SteamLaunch AppId=<id>`, which outlives the game's process
# tree, so quit, crash, kill and Steam "Stop" all end it) or a process from
# the named app list (process name, `.<name>-wrapped`, or argv0 basename).
#
# When the set of running games changes, the names go to the games file (one
# per line; no file = no game) and `power-profile sync` applies the effective
# profile: full-power while a game runs and auto=on, else the picked one.
# While any game runs, a logind `idle` block inhibitor is held (never
# `sleep`, so "Suspend now" still works), whatever auto says: controller play
# makes no keyboard/mouse input.
#
# Environment (set by the NixOS module; tests point it at a fake tree):
#   POWER_WATCH_APPS              named apps, one per line
#   POWER_WATCH_IGNORED_APPIDS    Steam AppIds that never count, space-separated
#   POWER_WATCH_INTERVAL          seconds between polls (default 2)
#   POWER_WATCH_RETRY_SECS        wait before retrying a failed sync or
#                                 inhibitor (default 30)
#   POWER_WATCH_PROC              procfs root for the named apps (default /proc)
#   POWER_WATCH_STEAM_ROOTS       Steam roots, one per line (default
#                                 ~/.local/share/Steam and ~/.steam/steam)
#   POWER_PROFILE_GAMES_FILE      games file; default
#                                 $XDG_RUNTIME_DIR/power-profile/games

interval=${POWER_WATCH_INTERVAL:-2}
retry_secs=${POWER_WATCH_RETRY_SECS:-30}
proc=${POWER_WATCH_PROC:-/proc}
ignored_appids=" ${POWER_WATCH_IGNORED_APPIDS:-} "
uid=$(id -u)
games_file=${POWER_PROFILE_GAMES_FILE:-${XDG_RUNTIME_DIR:-/run/user/$uid}/power-profile/games}

apps=()
if [ -n "${POWER_WATCH_APPS:-}" ]; then
  mapfile -t apps <<<"$POWER_WATCH_APPS"
fi

steam_roots=()
if [ -n "${POWER_WATCH_STEAM_ROOTS:-}" ]; then
  mapfile -t steam_roots <<<"$POWER_WATCH_STEAM_ROOTS"
else
  steam_roots=("${XDG_DATA_HOME:-$HOME/.local/share}/Steam" "$HOME/.steam/steam")
fi

# reaper's argv0 is its full path (…/ubuntu12_32/reaper).
reaper_re='(^|/)reaper SteamLaunch AppId=[0-9]+( |$)'

warn() {
  echo "power-watch: $*" >&2
}

# --- detection ---------------------------------------------------------------
# Runs every poll, so it forks only pgrep (each exec costs ms of CPU).

# Running games as sorted, unique keys: steam:<appid> / app:<name>.
found=()

add_found() {
  local key=$1 i n=${#found[@]}
  for ((i = 0; i < n; i++)); do
    if [[ ${found[i]} == "$key" ]]; then
      return 0
    elif [[ ${found[i]} > "$key" ]]; then
      break
    fi
  done
  found=("${found[@]:0:i}" "$key" "${found[@]:i}")
}

# Every running Steam launch.
scan_steam() {
  local line
  while IFS= read -r line; do
    if [[ $line =~ AppId=([0-9]+) ]] &&
      [[ $ignored_appids != *" ${BASH_REMATCH[1]} "* ]]; then
      add_found "steam:${BASH_REMATCH[1]}"
    fi
  done < <(pgrep -u "$uid" -af "$reaper_re")
}

# Every running process from the named list. Reads /proc/<pid>/{comm,cmdline}
# of this user's processes; comm is cut to 15 characters, so long names match
# through argv0 only.
scan_apps() {
  local pid comm argv0 base name
  while read -r pid; do
    comm=
    argv0=
    read -r comm 2>/dev/null <"$proc/$pid/comm" || continue
    IFS= read -r -d '' argv0 2>/dev/null <"$proc/$pid/cmdline" || true
    base=${argv0##*/}
    base=${base##*\\}
    for name in "${apps[@]}"; do
      case $comm in "$name" | ".$name-wrapped") add_found "app:$name" ;; esac
      case $base in "$name" | ".$name-wrapped") add_found "app:$name" ;; esac
    done
  done < <(pgrep -u "$uid")
}

scan() {
  found=()
  scan_steam
  if [ ${#apps[@]} -gt 0 ]; then
    scan_apps
  fi
}

# --- names -------------------------------------------------------------------

# Prints every steamapps dir: the roots' own plus the libraries listed in
# their libraryfolders.vdf.
steam_libraries() {
  local root vdf
  for root in "${steam_roots[@]}"; do
    [ -d "$root/steamapps" ] || continue
    echo "$root/steamapps"
    vdf=$root/steamapps/libraryfolders.vdf
    if [ -r "$vdf" ]; then
      sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1\/steamapps/p' "$vdf"
    fi
  done
}

# Prints the name of Steam app <appid> from its appmanifest; "Steam app
# <appid>" when there is none (non-Steam shortcuts, missing library).
steam_name() {
  local id=$1 dir name=
  while IFS= read -r dir; do
    if [ -r "$dir/appmanifest_$id.acf" ]; then
      name=$(sed -n 's/^[[:space:]]*"name"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/;T;p;q' \
        "$dir/appmanifest_$id.acf")
      # VDF escapes.
      name=${name//\\\"/\"}
      name=${name//\\\\/\\}
      if [ -n "$name" ]; then
        break
      fi
    fi
  done < <(steam_libraries)
  printf '%s\n' "${name:-Steam app $id}"
}

# Prints a display name per found game.
names() {
  local key
  for key in "${found[@]}"; do
    case $key in
      steam:*) steam_name "${key#steam:}" ;;
      app:*) printf '%s\n' "${key#app:}" ;;
    esac
  done
}

# --- games file + profile ----------------------------------------------------

# Writes the names (one per line) to the games file; no names = no file.
write_games() {
  local dir=${games_file%/*} tmp
  if [ -z "$1" ]; then
    rm -f "$games_file"
    return 0
  fi
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.games.XXXXXX")
  printf '%s\n' "$1" >"$tmp"
  mv -f "$tmp" "$games_file"
}

sync_pending=0
sync_retry_at=0

# Applies the effective profile and logs "<what>; effective=<profile>". A
# failed sync is retried from the main loop.
sync_profile() {
  local what=$1 out
  if out=$(power-profile sync 2>&1); then
    sync_pending=0
    echo "$what; effective=$(sed -n 's/^effective=//p' <<<"$out")"
  else
    sync_pending=1
    sync_retry_at=$((SECONDS + retry_secs))
    echo "$what"
    warn "power-profile sync failed, retrying in ${retry_secs}s: $out"
  fi
}

# --- idle inhibitor ----------------------------------------------------------

inhibit_pid=
inhibit_why=
inhibit_started=0

# True while background job <pid> runs (bash reaps it as soon as it exits).
# No `read` here: on_term calls it, and a `read` inside a trap that
# interrupted the poll's `read -t` reads the wrong fd and hangs.
is_running() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

# Holds `systemd-inhibit --what=idle` with <why>; restarts it when <why>
# changes or it died (at most every retry_secs). The new lock is taken before
# the old one is dropped, so idle is never briefly allowed.
hold_inhibitor() {
  local why=$1 old
  if is_running "$inhibit_pid"; then
    [ "$inhibit_why" != "$why" ] || return 0
  elif [ -n "$inhibit_pid" ]; then
    inhibit_why=$why
    if [ $((SECONDS - inhibit_started)) -lt "$retry_secs" ]; then
      return 0
    fi
    warn "idle inhibitor exited; restarting it"
  fi
  old=$inhibit_pid
  systemd-inhibit --what=idle --mode=block --who=power-watch --why="$why" \
    sleep infinity &
  inhibit_pid=$!
  inhibit_why=$why
  inhibit_started=$SECONDS
  if is_running "$old"; then
    kill "$old" 2>/dev/null || true
  fi
}

release_inhibitor() {
  if is_running "$inhibit_pid"; then
    kill "$inhibit_pid" 2>/dev/null || true
  fi
  inhibit_pid=
  inhibit_why=
}

# --- main --------------------------------------------------------------------

# Exits inside the trap: a trap that returns would let the poll's `read -t`
# wait out its timeout. The games file stays for ExecStopPost (`stop`).
on_term() {
  release_inhibitor
  exit 0
}

cmd_run() {
  local keys last=- names_now joined tick_fd _tick
  trap on_term TERM INT
  # Sleeps with `read -t` on a pipe nobody writes to: no fork per poll.
  exec {tick_fd}<> <(:)
  echo "watching for games every ${interval}s (named apps: ${#apps[@]})"
  while :; do
    scan
    keys=
    if [ ${#found[@]} -gt 0 ]; then
      printf -v keys '%s\n' "${found[@]}"
    fi
    if [ "$keys" != "$last" ]; then
      names_now=$(names)
      write_games "$names_now"
      if [ -n "$keys" ]; then
        joined=${names_now//$'\n'/, }
        hold_inhibitor "Game: $joined"
      else
        joined=none
        release_inhibitor
      fi
      sync_profile "games: $joined"
      last=$keys
    elif [ "$sync_pending" = 1 ] && [ "$SECONDS" -ge "$sync_retry_at" ]; then
      sync_profile "games: $joined (retry)"
    fi
    if [ -n "$keys" ]; then
      # Restarts a dead inhibitor.
      hold_inhibitor "$inhibit_why"
    fi
    # Later samplers (e.g. CPU / network load for the busy check) go here.
    read -r -t "$interval" -u "$tick_fd" _tick || true
  done
}

# A stopped watcher cannot see games end, so drop them and go back to the
# picked profile (a restarted watcher picks running games up again). Always
# syncs: a sync cut short by the stop may have left the game's profile
# applied; with nothing to change, sync starts no unit.
cmd_stop() {
  if [ -s "$games_file" ]; then
    echo "stopped: games cleared"
  fi
  rm -f "$games_file"
  if ! timeout 20 power-profile sync >/dev/null; then
    warn "power-profile sync failed"
  fi
}

case ${1:-run} in
  run) cmd_run ;;
  stop) cmd_stop ;;
  *)
    echo "usage: power-watch [run|stop]" >&2
    exit 2
    ;;
esac
