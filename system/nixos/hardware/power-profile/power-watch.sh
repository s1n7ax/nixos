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
# It also samples CPU and network load for the busy check (`power-profile
# can-sleep`): every POWER_WATCH_LOAD_EVERY seconds it writes the averages
# over the last POWER_WATCH_LOAD_WINDOW seconds to the load file.
#
# Environment (set by the NixOS module; tests point it at a fake tree):
#   POWER_WATCH_APPS              named apps, one per line
#   POWER_WATCH_IGNORED_APPIDS    Steam AppIds that never count, space-separated
#   POWER_WATCH_INTERVAL          seconds between polls (default 2)
#   POWER_WATCH_RETRY_SECS        wait before retrying a failed sync or
#                                 inhibitor (default 30)
#   POWER_WATCH_PROC              procfs root (default /proc)
#   POWER_WATCH_SYS               sysfs root (default /sys)
#   POWER_WATCH_STEAM_ROOTS       Steam roots, one per line (default
#                                 ~/.local/share/Steam and ~/.steam/steam)
#   POWER_WATCH_LOAD_EVERY        seconds between load samples (default 5)
#   POWER_WATCH_LOAD_WINDOW       seconds the load averages cover (default 60)
#   POWER_PROFILE_GAMES_FILE      games file; default
#                                 $XDG_RUNTIME_DIR/power-profile/games
#   POWER_PROFILE_LOAD_FILE       load file; default
#                                 $XDG_RUNTIME_DIR/power-profile/load

interval=${POWER_WATCH_INTERVAL:-2}
retry_secs=${POWER_WATCH_RETRY_SECS:-30}
proc=${POWER_WATCH_PROC:-/proc}
sys=${POWER_WATCH_SYS:-/sys}
ignored_appids=" ${POWER_WATCH_IGNORED_APPIDS:-} "
uid=$(id -u)
games_file=${POWER_PROFILE_GAMES_FILE:-${XDG_RUNTIME_DIR:-/run/user/$uid}/power-profile/games}
load_file=${POWER_PROFILE_LOAD_FILE:-${XDG_RUNTIME_DIR:-/run/user/$uid}/power-profile/load}
load_every=${POWER_WATCH_LOAD_EVERY:-5}
load_window=${POWER_WATCH_LOAD_WINDOW:-60}

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

warn() {
  echo "power-watch: $*" >&2
}

# --- detection ---------------------------------------------------------------
# Runs every poll, so it forks nothing: a pgrep per poll cost ~47 ms of CPU
# with ~500 processes. Only processes started in the last new_polls polls are
# read (a pid is new while it is above ns_last_pid of new_polls polls ago), so
# a process that becomes a game later than that (a slow launcher's exec) is
# missed. A pid found to be a game stays one while it lives.

# Polls a process counts as new: 30 s at the default interval.
new_polls=15

shopt -s nullglob

# Running games as sorted, unique keys: steam:<appid> / app:<name>.
found=()
# pid -> key of every game process seen and still running.
declare -A game_pids=()
# ns_last_pid at each of the last new_polls polls, oldest first.
pid_marks=()

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

# Sets key and succeeds when <pid> is one of this user's games: a Steam launch
# (`reaper SteamLaunch AppId=<id>`) or a process from the named list (process
# name, `.<name>-wrapped`, or argv0 basename; comm is cut to 15 characters, so
# long names match through argv0 only). One key per process, Steam first.
classify() {
  local pid=$1 argv=() comm base name
  key=
  [ -O "$proc/$pid" ] || return 1
  mapfile -d '' -t argv 2>/dev/null <"$proc/$pid/cmdline" || return 1
  base=${argv[0]-}
  base=${base##*/}
  if [ "$base" = reaper ] && [ "${argv[1]-}" = SteamLaunch ] &&
    [[ ${argv[2]-} =~ ^AppId=([0-9]+)$ ]]; then
    [[ $ignored_appids != *" ${BASH_REMATCH[1]} "* ]] || return 1
    key=steam:${BASH_REMATCH[1]}
    return 0
  fi
  [ ${#apps[@]} -gt 0 ] || return 1
  read -r comm 2>/dev/null <"$proc/$pid/comm" || return 1
  base=${base##*\\}
  for name in "${apps[@]}"; do
    case $comm in "$name" | ".$name-wrapped") key=app:$name ;; esac
    case $base in "$name" | ".$name-wrapped") key=app:$name ;; esac
    [ -z "$key" ] || return 0
  done
  return 1
}

scan() {
  local floor=${pid_marks[0]:-0} last p pid
  local -A now=()
  if read -r last 2>/dev/null <"$proc/sys/kernel/ns_last_pid"; then
    # The pid counter wrapped: every pid counts as new until the marks refill.
    if [ "$last" -lt "$floor" ]; then
      pid_marks=()
      floor=0
    fi
    pid_marks+=("$last")
    if [ ${#pid_marks[@]} -gt "$new_polls" ]; then
      pid_marks=("${pid_marks[@]:1}")
    fi
  fi
  for pid in "${!game_pids[@]}"; do
    if [ -e "$proc/$pid" ]; then
      now[$pid]=${game_pids[$pid]}
    fi
  done
  # This loop is most of a poll's CPU, so it only compares numbers.
  for p in "$proc"/[0-9]*; do
    pid=${p##*/}
    ((pid > floor)) || continue
    if [ -z "${now[$pid]+x}" ] && classify "$pid"; then
      now[$pid]=$key
    fi
  done
  found=()
  game_pids=()
  for pid in "${!now[@]}"; do
    game_pids[$pid]=${now[$pid]}
    add_found "${now[$pid]}"
  done
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
  local id=$1 dir dirs name=
  # Read in full first: leaving a `< <(…)` loop early makes the writer's
  # echo fail with "Broken pipe".
  mapfile -t dirs < <(steam_libraries)
  for dir in "${dirs[@]}"; do
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
  done
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

# --- load (busy check) -------------------------------------------------------
# CPU: busy jiffies of all CPUs over all jiffies, times the CPU count, so a
# window with a suspend in it still gives the right core count (the dev VM's
# vCPUs are host threads, so they count). Network: bytes received + sent on
# the default-route interface (the dev VM's user-mode network goes through
# host sockets, so its traffic shows there too). Everything is read with
# builtins; one `mv` per sample keeps the file atomic.

# Samples in the window, oldest first: uptime in 1/100 s, busy and total
# jiffies, rx and tx bytes.
load_t=()
load_busy=()
load_total=()
load_rx=()
load_tx=()
load_iface=
load_next=0
ncpu=0

count_cpus() {
  local name _rest
  ncpu=0
  while read -r name _rest; do
    case $name in cpu[0-9]*) ncpu=$((ncpu + 1)) ;; esac
  done <"$proc/stat"
  [ "$ncpu" -gt 0 ] || ncpu=1
}

# Sets iface to the default-route interface with the lowest metric; empty
# when there is none (no network).
default_iface() {
  local ifc dst _gw _flags _ref _use metric mask _rest best_metric=
  iface=
  while read -r ifc dst _gw _flags _ref _use metric mask _rest; do
    [ "$dst" = 00000000 ] && [ "$mask" = 00000000 ] || continue
    if [ -z "$iface" ] || [ "$metric" -lt "$best_metric" ]; then
      iface=$ifc
      best_metric=$metric
    fi
  done 2>/dev/null <"$proc/net/route" || true
}

load_reset() {
  load_t=()
  load_busy=()
  load_total=()
  load_rx=()
  load_tx=()
}

load_drop_oldest() {
  load_t=("${load_t[@]:1}")
  load_busy=("${load_busy[@]:1}")
  load_total=("${load_total[@]:1}")
  load_rx=("${load_rx[@]:1}")
  load_tx=("${load_tx[@]:1}")
}

# Takes a sample and rewrites the load file:
#   time=<epoch> span=<s> cores=<n.nn> cores_centi=<n> net_kib=<KiB/s>
#   rx_kib=<KiB/s> tx_kib=<KiB/s> iface=<name>
# The window restarts after a gap of more than 3 samples (suspend), on an
# interface change, or when a counter goes back (interface re-created).
load_sample() {
  local up _cpu user nice system idle iowait irq softirq steal _rest busy total
  local iface rx=0 tx=0 n span dbusy dtotal centi rx_kib tx_kib tmp
  read -r up _rest <"$proc/uptime" || return 0
  up=${up/./}
  up=$((10#$up))
  read -r _cpu user nice system idle iowait irq softirq steal _rest <"$proc/stat" || return 0
  busy=$((user + nice + system + irq + softirq + ${steal:-0}))
  total=$((busy + idle + iowait))
  default_iface
  if [ -n "$iface" ]; then
    read -r rx 2>/dev/null <"$sys/class/net/$iface/statistics/rx_bytes" || rx=0
    read -r tx 2>/dev/null <"$sys/class/net/$iface/statistics/tx_bytes" || tx=0
  fi

  n=${#load_t[@]}
  if [ "$n" -gt 0 ] &&
    { [ $((up - load_t[n - 1])) -gt $((3 * load_every * 100)) ] ||
      [ "$iface" != "$load_iface" ] ||
      [ "$rx" -lt "${load_rx[n - 1]}" ] || [ "$tx" -lt "${load_tx[n - 1]}" ] ||
      [ "$total" -lt "${load_total[n - 1]}" ]; }; then
    load_reset
    n=0
  fi
  load_iface=$iface
  load_t+=("$up")
  load_busy+=("$busy")
  load_total+=("$total")
  load_rx+=("$rx")
  load_tx+=("$tx")
  n=$((n + 1))
  # Keep the newest sample that is at least a window old as the base.
  while [ "$n" -gt 2 ] && [ $((up - load_t[1])) -ge $((load_window * 100)) ]; do
    load_drop_oldest
    n=$((n - 1))
  done
  [ "$n" -ge 2 ] || return 0

  span=$((up - load_t[0]))
  [ "$span" -gt 0 ] || return 0
  dbusy=$((busy - load_busy[0]))
  dtotal=$((total - load_total[0]))
  centi=0
  if [ "$dtotal" -gt 0 ]; then
    centi=$((dbusy * ncpu * 100 / dtotal))
  fi
  # bytes / 1024 / (span / 100) KiB/s
  rx_kib=$(((rx - load_rx[0]) * 100 / 1024 / span))
  tx_kib=$(((tx - load_tx[0]) * 100 / 1024 / span))

  tmp=$load_file.tmp
  if ! printf 'time=%s\nspan=%s\ncores=%d.%02d\ncores_centi=%s\nnet_kib=%s\nrx_kib=%s\ntx_kib=%s\niface=%s\n' \
    "$EPOCHSECONDS" $((span / 100)) $((centi / 100)) $((centi % 100)) "$centi" \
    $((rx_kib + tx_kib)) "$rx_kib" "$tx_kib" "${iface:-none}" 2>/dev/null >"$tmp" ||
    ! mv -f "$tmp" "$load_file"; then
    warn "cannot write $load_file"
  fi
}

# Samples when due (every load_every seconds).
load_tick() {
  if [ "$SECONDS" -ge "$load_next" ]; then
    load_next=$((SECONDS + load_every))
    load_sample
  fi
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
  mkdir -p "${load_file%/*}"
  count_cpus
  echo "watching for games every ${interval}s (named apps: ${#apps[@]});" \
    "load every ${load_every}s over ${load_window}s (${ncpu} CPUs)"
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
    load_tick
    read -r -t "$interval" -u "$tick_fd" _tick || true
  done
}

# A stopped watcher cannot see games end, so drop them and go back to the
# picked profile (a restarted watcher picks running games up again). Always
# syncs: a sync cut short by the stop may have left the game's profile
# applied; with nothing to change, sync starts no unit. The load file goes
# too: no load data counts as busy.
cmd_stop() {
  if [ -s "$games_file" ]; then
    echo "stopped: games cleared"
  fi
  rm -f "$games_file" "$load_file" "$load_file.tmp"
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
