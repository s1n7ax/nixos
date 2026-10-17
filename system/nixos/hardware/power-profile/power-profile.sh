# power-profile: pick the desktop's CPU/GPU power profile. The single entry
# point for profile changes: the rofi menu and the game watcher call it too.
#
# State (persists across reboots), one key=value per line:
#   profile=<picked profile>   what runs when no game overrides it
#   auto=on|off                "Auto (follow games)": a running game switches
#                              to full-power
#
# The effective profile is `disabled` or `full-power` when picked, else
# `full-power` while auto=on and the games file is non-empty, else the picked
# one. Applying goes through the root unit power-profile-apply@<profile>,
# which polkit lets this user start without a password.
#
# Display (Hyprland): the power-saving profiles (strict, short-boosts,
# full-speed-heavy) run the desktop in display mode `eco` (low refresh rate,
# no animations/blur/shadows); full-power, disabled and games run `full`
# (full refresh rate, effects as configured). The mode the screen is in is
# kept in the display file, which Hyprland's config reads on every load; a
# running session is switched with `hyprctl eval 'PowerDisplay("<mode>")'`.
# The display switches before the CPU/GPU apply (a game reads the refresh
# rate at its start). `set` and `auto` switch at once, and so does `sync`
# when a game starts. When a game ends, `sync` leaves the switch back to
# `eco` pending: the idle screen-off calls `power-profile display apply`, so
# the blank of a mode switch is only seen when the user caused it.
#
# Every change of the effective profile (and every `set`/`auto`) shows a
# desktop notification.
#
# Idle hooks (hypridle, the power-idle user unit): `idle screen-off` applies
# a pending display mode, lets the modeset settle, then turns the screen off
# (DPMS); `idle screen-on` turns it on. hypridle runs both without waiting,
# so a flag file under a lock makes a screen-off that was overtaken by input
# leave the screen on. `idle after-sleep` restarts hypridle's timers after a
# wake.
#
# Sleep: hypridle suspends after the idle timeout only when `can-sleep` says
# nothing is busy (exit 0), and asks again every 30 s while it says busy.
# Busy signals, cheapest first: Stay awake, a running game, CPU and network
# load (averages sampled by power-watch), SSH sessions into the desktop or a
# VM, agent sessions (Claude Code, pi, opencode, even idle) on the host and
# in the dev VM (its status share), a third-party logind sleep block,
# playing audio. "Stay awake" is a wall-clock deadline (or "until off") in
# the runtime dir: it does not survive a reboot, and time asleep counts. It
# blocks only the suspend; the screen still turns off. "Suspend now"
# (`suspend --now`) ignores all of it.
#
# Environment (set by the NixOS module; tests point it at a fake tree):
#   POWER_PROFILE_STATE_FILE         persisted state
#   POWER_PROFILE_RUN_DIR            the root side's applied record
#   POWER_PROFILE_DEFAULT            profile used while nothing is picked
#   POWER_PROFILE_GAMES_FILE         running games, one per line (game
#                                    watcher); default
#                                    $XDG_RUNTIME_DIR/power-profile/games
#   POWER_PROFILE_DISPLAY_FILE       display mode the screen is in (eco|full)
#   POWER_PROFILE_DISPLAY_ECO_MODE   monitor mode of `eco` (notification text)
#   POWER_PROFILE_DISPLAY_FULL_MODE  monitor mode of `full` (notification text)
#   POWER_PROFILE_HYPRCTL            hyprctl path; empty = no display switching
#   POWER_PROFILE_MODESET_SETTLE     seconds a display switch gets before
#                                    the screen turns off (default 3)
#   POWER_PROFILE_IDLE               1 = idle stack on (menu sleep rows)
#   POWER_PROFILE_SCREEN_OFF_TIMEOUT, POWER_PROFILE_SUSPEND_TIMEOUT
#                                    idle timeouts in seconds (popup text;
#                                    empty suspend timeout = no auto-suspend)
#   POWER_PROFILE_LOAD_FILE          load averages from power-watch; default
#                                    $XDG_RUNTIME_DIR/power-profile/load
#   POWER_PROFILE_BUSY_CPU_CENTI     busy at this many 1/100 cores (150)
#   POWER_PROFILE_BUSY_NET_KIBPS     busy at this many KiB/s (128)
#   POWER_PROFILE_BUSY_AGENTS        agent process names (comm), extended
#                                    regex; empty = no agent check
#   POWER_PROFILE_SSH_PORTS          local ports of SSH sessions, space-
#                                    separated (sshd and VM forwards)
#   POWER_PROFILE_AUDIO_IGNORE       output streams that never count, one
#                                    per line
#   POWER_PROFILE_VM_NAME, POWER_PROFILE_VM_UNIT,
#   POWER_PROFILE_VM_STATUS_FILE     the dev VM and its status file; empty =
#                                    no VM check
#   POWER_PROFILE_LOAD_MAX_AGE       seconds the load file stays valid (30)
#   POWER_PROFILE_VM_STATUS_MAX_AGE  seconds the VM status stays valid (60)

state_file=${POWER_PROFILE_STATE_FILE:-/var/lib/power-profile/state}
state_dir=${state_file%/*}
run_dir=${POWER_PROFILE_RUN_DIR:-/run/power-profile}
applied_file=$run_dir/applied
default_profile=${POWER_PROFILE_DEFAULT:-disabled}
games_file=${POWER_PROFILE_GAMES_FILE:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/power-profile/games}

runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
display_file=${POWER_PROFILE_DISPLAY_FILE:-$state_dir/display}
eco_mode=${POWER_PROFILE_DISPLAY_ECO_MODE:-}
full_mode=${POWER_PROFILE_DISPLAY_FULL_MODE:-}
hyprctl=${POWER_PROFILE_HYPRCTL:-}
modeset_settle=${POWER_PROFILE_MODESET_SETTLE:-3}
idle_dir=$runtime_dir/power-profile
screen_off_flag=$idle_dir/screen-off

idle_on=${POWER_PROFILE_IDLE:-}
screen_off_timeout=${POWER_PROFILE_SCREEN_OFF_TIMEOUT:-}
suspend_timeout=${POWER_PROFILE_SUSPEND_TIMEOUT:-}
stay_awake_file=$idle_dir/stay-awake
busy_file=$idle_dir/busy
load_file=${POWER_PROFILE_LOAD_FILE:-$idle_dir/load}
busy_cpu_centi=${POWER_PROFILE_BUSY_CPU_CENTI:-150}
busy_net_kibps=${POWER_PROFILE_BUSY_NET_KIBPS:-128}
agents_re=${POWER_PROFILE_BUSY_AGENTS:-}
ssh_ports=${POWER_PROFILE_SSH_PORTS:-}
audio_ignore=${POWER_PROFILE_AUDIO_IGNORE:-}
vm_name=${POWER_PROFILE_VM_NAME:-}
vm_unit=${POWER_PROFILE_VM_UNIT:-}
vm_status_file=${POWER_PROFILE_VM_STATUS_FILE:-}
load_max_age=${POWER_PROFILE_LOAD_MAX_AGE:-30}
vm_status_max_age=${POWER_PROFILE_VM_STATUS_MAX_AGE:-60}

# Keep in sync with features.hardware.power-profile.profiles and
# power-profile-ctl.sh.
profiles=(strict short-boosts full-speed-heavy disabled full-power)

die() {
  echo "power-profile: $*" >&2
  exit 1
}

warn() {
  echo "power-profile: $*" >&2
}

usage() {
  cat <<EOF
Usage: power-profile [command]

Commands:
  status          picked profile, auto, game, effective, applied and display
                  (default)
  get             print the picked profile
  set <profile>   pick a profile, save it and apply it now
  list            list profiles as "<profile><TAB><label>"
  auto [on|off]   print or set "Auto (follow games)"
  sync            apply the effective profile if it is not applied yet (game
                  watcher); a game start switches the display at once, a game
                  end leaves it to \`display apply\`
  menu            pick a profile or toggle auto in a rofi menu
  display [apply] print the display mode, or apply the one the effective
                  profile wants now
  idle <hook>     hypridle hooks: screen-off (apply a pending display mode,
                  then DPMS off), screen-on, after-sleep (restart the idle
                  timers)
  can-sleep [--explain]
                  exit 0 when nothing keeps the PC awake, else print why and
                  exit 1 (hypridle's suspend condition); --explain shows
                  every signal
  suspend --now|--idle
                  --now: suspend at once, past every busy signal and logind
                  sleep block (menu); --idle: plain suspend (hypridle)
  stay-awake [<N>h|<N>m|on|off]
                  print, or block auto-suspend for a while (wall clock, also
                  counts time asleep) or until off; the screen still turns
                  off
  help            show this help

Profiles: ${profiles[*]}
EOF
}

label() {
  case $1 in
    strict) echo "Strict caps" ;;
    short-boosts) echo "Short boosts" ;;
    full-speed-heavy) echo "Full speed heavy" ;;
    disabled) echo "Disabled (stock)" ;;
    full-power) echo "Full power (force)" ;;
  esac
}

valid_profile() {
  local p
  for p in "${profiles[@]}"; do
    [ "$p" = "$1" ] && return 0
  done
  return 1
}

# Prints the value of <key> from a key=value file; empty when missing.
read_kv() {
  local file=$1 key=$2 k v value=
  [ -r "$file" ] || return 0
  while IFS='=' read -r k v; do
    if [ "$k" = "$key" ]; then
      value=$v
    fi
  done <"$file"
  printf '%s' "$value"
}

picked() {
  local profile
  profile=$(read_kv "$state_file" profile)
  valid_profile "$profile" || profile=$default_profile
  printf '%s' "$profile"
}

auto_mode() {
  local auto
  auto=$(read_kv "$state_file" auto)
  case $auto in
    on | off) printf '%s' "$auto" ;;
    *) printf on ;;
  esac
}

game_running() {
  [ -s "$games_file" ]
}

effective() {
  local profile
  profile=$(picked)
  case $profile in
    disabled | full-power) ;;
    *)
      if [ "$(auto_mode)" = on ] && game_running; then
        profile=full-power
      fi
      ;;
  esac
  printf '%s' "$profile"
}

# Label of the effective profile; a game's full power says so.
effective_label() {
  local profile
  profile=$(effective)
  if [ "$profile" != "$(picked)" ]; then
    echo "Full power (game)"
  else
    label "$profile"
  fi
}

# Serialises state changes between the menu, the game watcher and the shell.
lock() {
  [ -d "$state_dir" ] || die "$state_dir does not exist"
  exec 9<"$state_dir"
  flock -w 30 9 || die "timed out waiting for the state lock"
}

write_state() {
  local tmp
  tmp=$(mktemp "$state_dir/.state.XXXXXX") || die "cannot write to $state_dir"
  printf 'profile=%s\nauto=%s\n' "$1" "$2" >"$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$state_file"
}

apply() {
  local unit="power-profile-apply@$1.service"
  if ! systemctl --no-ask-password start "$unit"; then
    notify critical "Power: $(label "$1") failed" "See: journalctl -b -u $unit"
    die "applying $1 failed; see: journalctl -b -u $unit"
  fi
}

# Applies the effective profile if it is not applied yet (or the last apply
# failed); returns 1 when nothing had to be applied.
sync_applied() {
  local want
  want=$(effective)
  if [ "$(read_kv "$applied_file" profile)" = "$want" ] &&
    [ "$(read_kv "$applied_file" result)" = ok ]; then
    return 1
  fi
  apply "$want"
}

# --- Display ---------------------------------------------------------------

# Display mode a profile wants.
display_for() {
  case $1 in
    strict | short-boosts | full-speed-heavy) printf eco ;;
    *) printf full ;;
  esac
}

# Display mode the screen is in; a missing file means `full` (stock).
display_shown() {
  local mode=
  if [ -r "$display_file" ]; then
    IFS= read -r mode <"$display_file" || true
  fi
  case $mode in
    eco | full) printf '%s' "$mode" ;;
    *) printf full ;;
  esac
}

write_display() {
  local tmp
  tmp=$(mktemp "${display_file%/*}/.display.XXXXXX") ||
    die "cannot write to ${display_file%/*}"
  printf '%s\n' "$1" >"$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$display_file"
}

# hyprctl for the running Hyprland session. A systemd user service may have
# no HYPRLAND_INSTANCE_SIGNATURE (started before Hyprland imported it) or a
# stale one (Hyprland restarted); then use the oldest live instance (-i 0).
hypr() {
  local sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
  if [ -n "$sig" ] && [ -S "$runtime_dir/hypr/$sig/.socket.sock" ]; then
    "$hyprctl" "$@"
  else
    "$hyprctl" -i 0 "$@"
  fi
}

hypr_session() {
  local socket
  for socket in "$runtime_dir"/hypr/*/.socket.sock; do
    [ -S "$socket" ] && return 0
  done
  return 1
}

# Saves display mode $1 for the next config load and switches a running
# Hyprland session to it. PowerDisplay does nothing when the mode is already
# shown. Without a session the mode applies when Hyprland starts. A failed
# switch is reported in $display_error, never fatal.
display_error=
display_set() {
  local out
  display_error=
  write_display "$1"
  [ -n "$hyprctl" ] && hypr_session || return 0
  out=$(hypr eval "PowerDisplay(\"$1\")" 2>&1) || true
  if [ "$out" != ok ]; then
    display_error=${out:-no answer from hyprctl}
    warn "switching the display to $1 failed: $display_error"
  fi
}

# After a game-watcher sync: switch to `full` at once (a game started), but
# leave a switch back to `eco` (a game ended) pending for the idle screen-off
# (`power-profile display apply`).
sync_display() {
  if [ "$(display_for "$(effective)")" = full ]; then
    display_set full
  fi
}

# "3440x1440@60.00Hz" -> "60 Hz"; the mode name when the monitor mode is not
# known.
refresh_text() {
  local mode=$2 rate
  [ -n "$mode" ] || {
    printf '%s' "$1"
    return 0
  }
  rate=${mode##*@}
  rate=${rate%Hz}
  rate=${rate%.00}
  printf '%s Hz' "$rate"
}

display_text() {
  case $1 in
    eco) refresh_text eco "$eco_mode" ;;
    full) refresh_text full "$full_mode" ;;
  esac
}

display_status() {
  echo "display=$(display_shown)"
  echo "display_target=$(display_for "$(effective)")"
}

# --- Notifications ---------------------------------------------------------

# notify <urgency> <summary> <body> [<stack tag>]; best effort. Also works
# from a systemd user service (session bus at $XDG_RUNTIME_DIR/bus).
notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$runtime_dir/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"
  fi
  # The stack tag makes dunst replace the previous popup of its kind
  # (power-profile: profile changes, power-sleep: sleep controls).
  timeout 5 notify-send --app-name=power-profile --urgency="$1" \
    --hint=string:x-dunst-stack-tag:"${4:-power-profile}" "$2" "$3" \
    >/dev/null 2>&1 || true
}

# dunst renders markup. The replacements are quoted: an unquoted & would
# insert the match (bash 5.2 patsub_replacement).
escape_markup() {
  local s=$1
  s=${s//&/'&amp;'}
  s=${s//</'&lt;'}
  s=${s//>/'&gt;'}
  printf '%s' "$s"
}

# Notifies the current state: effective profile, game, auto and display.
notify_state() {
  local urgency=$1 profile body shown want
  profile=$(effective)
  body=
  if game_running; then
    body+="Game: $(paste -sd, "$games_file")"$'\n'
  fi
  if [ "$profile" != "$(picked)" ]; then
    body+="Back to $(label "$(picked)") when the game ends"$'\n'
  fi
  body+="Auto (follow games): $(auto_mode)"$'\n'
  shown=$(display_shown)
  want=$(display_for "$profile")
  if [ "$shown" = "$want" ]; then
    body+="Display: $(display_text "$shown")"
    [ "$shown" = full ] || body+=", no animations"
  else
    body+="Display: $(display_text "$shown") until the next screen-off, then $(display_text "$want")"
  fi
  if [ -n "$display_error" ]; then
    body+=$'\n'"Display switch failed: $display_error"
  fi
  notify "$urgency" "Power: $(effective_label)" "$(escape_markup "$body")"
}

# --- Commands --------------------------------------------------------------

status() {
  local games=none
  if game_running; then
    games=$(paste -sd, "$games_file")
  fi
  echo "profile=$(picked)"
  echo "auto=$(auto_mode)"
  echo "game=$games"
  echo "effective=$(effective)"
  echo "applied=$(read_kv "$applied_file" profile)"
  echo "result=$(read_kv "$applied_file" result)"
  display_status
  echo "stay_awake=$(stay_awake_text "$(stay_awake_until)")"
}

cmd_set() {
  [ $# -eq 1 ] || die "usage: power-profile set <profile>"
  valid_profile "$1" || die "unknown profile '$1' (one of: ${profiles[*]})"
  lock
  write_state "$1" "$(auto_mode)"
  display_set "$(display_for "$(effective)")"
  apply "$(effective)"
  notify_state normal
  status
}

cmd_auto() {
  case $# in
    0)
      auto_mode
      echo
      return 0
      ;;
    1) ;;
    *) die "usage: power-profile auto [on|off]" ;;
  esac
  case $1 in
    on | off) ;;
    *) die "usage: power-profile auto [on|off]" ;;
  esac
  lock
  write_state "$(picked)" "$1"
  display_set "$(display_for "$(effective)")"
  sync_applied || true
  notify_state normal
  status
}

cmd_sync() {
  [ $# -eq 0 ] || die "usage: power-profile sync"
  lock
  sync_display
  if sync_applied; then
    notify_state low
  fi
  status
}

cmd_display() {
  case $# in
    0)
      display_status
      return 0
      ;;
    1) [ "$1" = apply ] || die "usage: power-profile display [apply]" ;;
    *) die "usage: power-profile display [apply]" ;;
  esac
  lock
  display_set "$(display_for "$(effective)")"
  display_status
  [ -z "$display_error" ] || exit 1
}

# --- Idle (hypridle hooks) --------------------------------------------------

# Serialises screen-off and screen-on: hypridle starts them without waiting.
idle_lock() {
  mkdir -p "$idle_dir"
  exec 8>"$idle_dir/idle.lock"
  flock -w 30 8 || die "timed out waiting for the idle lock"
}

# dpms on|off for every output; failures are logged, never fatal.
dpms() {
  local out
  [ -n "$hyprctl" ] && hypr_session || return 0
  out=$(hypr dispatch "hl.dsp.dpms({ action = \"$1\" })" 2>&1) || true
  [ "$out" = ok ] || warn "dpms $1 failed: ${out:-no answer from hyprctl}"
}

idle_screen_off() {
  local before after
  idle_lock
  : >"$screen_off_flag"
  flock -u 8

  # A display switch left pending after a game happens now, while nobody
  # watches. Hyprland modesets on the next frame; one landing after DPMS
  # off would blank the screen right after the wake, so let it settle.
  lock
  before=$(display_shown)
  display_set "$(display_for "$(effective)")"
  after=$(display_shown)
  flock -u 9
  if [ "$before" != "$after" ]; then
    sleep "$modeset_settle"
  fi

  # Input during the switch already ran screen-on and removed the flag.
  idle_lock
  if [ -e "$screen_off_flag" ]; then
    dpms off
  fi
}

idle_screen_on() {
  idle_lock
  rm -f "$screen_off_flag"
  dpms on
}

# hypridle fires each timeout once per idle period, so a wake without input
# would never turn the screen off again. force_idle(0) counts as input: the
# screen comes on and the timers start from 0.
idle_after_sleep() {
  local out
  [ -n "$hyprctl" ] && hypr_session || return 0
  out=$(hypr dispatch 'hl.dsp.force_idle(0)' 2>&1) || true
  [ "$out" = ok ] || warn "restarting the idle timers failed: ${out:-no answer from hyprctl}"
}

cmd_idle() {
  [ $# -eq 1 ] || die "usage: power-profile idle screen-off|screen-on|after-sleep"
  case $1 in
    screen-off) idle_screen_off ;;
    screen-on) idle_screen_on ;;
    after-sleep) idle_after_sleep ;;
    *) die "usage: power-profile idle screen-off|screen-on|after-sleep" ;;
  esac
}

# --- Sleep: Stay awake -------------------------------------------------------

is_number() {
  case $1 in
    '' | *[!0-9]*) return 1 ;;
  esac
  [ ${#1} -le 18 ]
}

# Prints the Stay awake deadline (epoch) or "forever"; nothing when off or
# past.
stay_awake_until() {
  local until
  until=$(read_kv "$stay_awake_file" until)
  if [ "$until" = forever ]; then
    printf forever
  elif is_number "$until" && [ "$until" -gt "$EPOCHSECONDS" ]; then
    printf '%s' "$until"
  fi
  return 0
}

# "off", "until off" or "until HH:MM" for a stay_awake_until value.
stay_awake_text() {
  case $1 in
    '') printf off ;;
    forever) printf 'until off' ;;
    *) printf 'until %(%H:%M)T' "$1" ;;
  esac
}

# "2 min" for 120, "90 s" for 90.
duration_text() {
  if [ $(($1 % 60)) -eq 0 ]; then
    printf '%s min' $(($1 / 60))
  else
    printf '%s s' "$1"
  fi
}

# Popup body: what idle does while Stay awake is off.
sleep_rules_text() {
  local text=
  if [ -n "$suspend_timeout" ]; then
    text="Suspends after $(duration_text "$suspend_timeout") idle when nothing is busy."
  else
    text="Auto-suspend is off."
  fi
  printf '%s' "$text"
}

screen_still_off_text() {
  if [ -n "$screen_off_timeout" ]; then
    printf 'The screen still turns off after %s.' "$(duration_text "$screen_off_timeout")"
  fi
}

# The transient timer that ends a timed Stay awake (and pops a notice). It
# is a realtime timer: a deadline passed while asleep fires right after the
# wake. Unit names carry the deadline; any old ones are stopped first.
stay_awake_timer() {
  local self
  systemctl --user stop 'power-stay-awake-*.timer' >/dev/null 2>&1 || true
  [ -n "$1" ] || return 0
  case $0 in
    /*) self=$0 ;;
    *) self=$PWD/$0 ;;
  esac
  if ! systemd-run --user --quiet --collect --unit="power-stay-awake-$1" \
    --on-calendar="@$1" --timer-property=AccuracySec=1s \
    -- "$self" stay-awake expire >/dev/null 2>&1; then
    warn "could not start the Stay awake timer; it still ends at $(printf '%(%H:%M)T' "$1"), with no popup"
  fi
}

write_stay_awake() {
  local tmp
  mkdir -p "$idle_dir"
  tmp=$(mktemp "$idle_dir/.stay-awake.XXXXXX") || die "cannot write to $idle_dir"
  printf 'until=%s\n' "$1" >"$tmp"
  mv -f "$tmp" "$stay_awake_file"
}

cmd_stay_awake() {
  local arg secs until
  case $# in
    0)
      stay_awake_text "$(stay_awake_until)"
      echo
      return 0
      ;;
    1) arg=$1 ;;
    *) die "usage: power-profile stay-awake [<N>h|<N>m|on|off]" ;;
  esac
  idle_lock
  case $arg in
    off)
      rm -f "$stay_awake_file"
      stay_awake_timer ""
      notify normal "Stay awake: off" "$(sleep_rules_text)" power-sleep
      ;;
    on)
      write_stay_awake forever
      stay_awake_timer ""
      notify normal "Stay awake until off" \
        "No auto-suspend until you turn it off."$'\n'"$(screen_still_off_text)" power-sleep
      ;;
    expire)
      # The timer's call: ends a deadline that has passed (allow 1 s early).
      until=$(read_kv "$stay_awake_file" until)
      if is_number "$until" && [ "$until" -le $((EPOCHSECONDS + 1)) ]; then
        rm -f "$stay_awake_file"
        notify normal "Stay awake ended" "$(sleep_rules_text)" power-sleep
      fi
      ;;
    *)
      if [[ $arg =~ ^([1-9][0-9]{0,2})h$ ]]; then
        secs=$((BASH_REMATCH[1] * 3600))
      elif [[ $arg =~ ^([1-9][0-9]{0,4})m$ ]]; then
        secs=$((BASH_REMATCH[1] * 60))
      else
        die "usage: power-profile stay-awake [<N>h|<N>m|on|off]"
      fi
      until=$((EPOCHSECONDS + secs))
      write_stay_awake "$until"
      stay_awake_timer "$until"
      notify normal "Stay awake $(stay_awake_text "$until")" \
        "No auto-suspend until then."$'\n'"$(screen_still_off_text)" power-sleep
      ;;
  esac
  stay_awake_text "$(stay_awake_until)"
  echo
}

# --- Sleep: busy check (can-sleep) -------------------------------------------

explain=0
busy_reasons=()

# signal <name> busy|ok <detail>
signal() {
  if [ "$2" = busy ]; then
    busy_reasons+=("$1: $3")
  fi
  if [ "$explain" = 1 ]; then
    if [ "$2" = busy ]; then
      printf '%s: BUSY (%s)\n' "$1" "$3"
    else
      printf '%s: ok (%s)\n' "$1" "$3"
    fi
  fi
  return 0
}

# Reads a key=value file into the kv array; fails when it is unreadable.
declare -A kv=()
read_kv_all() {
  local k v
  kv=()
  [ -f "$1" ] && [ -r "$1" ] || return 1
  while IFS='=' read -r k v; do
    [ -n "$k" ] && kv[$k]=$v
  done <"$1"
  return 0
}

check_stay_awake() {
  local until
  until=$(stay_awake_until)
  if [ -n "$until" ]; then
    signal stay-awake busy "$(stay_awake_text "$until")"
  else
    signal stay-awake ok off
  fi
}

check_game() {
  if game_running; then
    signal game busy "$(paste -sd, "$games_file")"
  else
    signal game ok none
  fi
}

# CPU and network averages from power-watch. No fresh data counts as busy:
# heavy work could be running unseen.
check_load() {
  local age centi cores net rx tx span iface limit
  if ! read_kv_all "$load_file" || ! is_number "${kv[time]:-}"; then
    signal load busy "no load data from power-watch (systemctl --user status power-watch)"
    return 0
  fi
  age=$((EPOCHSECONDS - kv[time]))
  if [ "$age" -gt "$load_max_age" ] || [ "$age" -lt -5 ]; then
    signal load busy "load data ${age} s old (systemctl --user status power-watch)"
    return 0
  fi
  centi=${kv[cores_centi]:-}
  net=${kv[net_kib]:-}
  if ! is_number "$centi" || ! is_number "$net"; then
    signal load busy "load data unreadable"
    return 0
  fi
  cores=${kv[cores]:-?}
  span=${kv[span]:-?}
  rx=${kv[rx_kib]:-?}
  tx=${kv[tx_kib]:-?}
  iface=${kv[iface]:-?}
  if [ "$centi" -ge "$busy_cpu_centi" ]; then
    printf -v limit '%d.%02d' $((busy_cpu_centi / 100)) $((busy_cpu_centi % 100))
    signal cpu busy "$cores cores over ${span} s, busy at $limit"
  else
    signal cpu ok "$cores cores over ${span} s"
  fi
  if [ "$net" -ge "$busy_net_kibps" ]; then
    signal network busy "$net KiB/s on $iface (rx $rx, tx $tx) over ${span} s, busy at $busy_net_kibps"
  else
    signal network ok "$net KiB/s on $iface (rx $rx, tx $tx)"
  fi
}

# Established TCP connections to sshd or to a VM's forwarded SSH port
# (ControlPersist masters and -N tunnels count).
check_ssh() {
  local filter='' port out n peers local_addr peer_addr
  if [ -z "$ssh_ports" ]; then
    signal ssh ok "no SSH ports"
    return 0
  fi
  for port in $ssh_ports; do
    filter+="${filter:+ or }sport = :$port"
  done
  if ! out=$(ss -Htn state established "( $filter )" 2>&1); then
    signal ssh busy "ss failed: $out"
    return 0
  fi
  n=0
  peers=
  while read -r _ _ local_addr peer_addr _; do
    [ -n "${peer_addr:-}" ] || continue
    n=$((n + 1))
    [ "$n" -gt 3 ] || peers+="${peers:+, }${peer_addr} -> ${local_addr##*:}"
  done <<<"$out"
  if [ "$n" -gt 0 ]; then
    signal ssh busy "$n session(s): $peers"
  else
    signal ssh ok "none on ports $ssh_ports"
  fi
}

# "claude 1, pi 2" from `pgrep -l` lines ("<pid> <comm>").
agents_detail() {
  local _pid name detail=
  local -A per=()
  while read -r _pid name; do
    [ -n "${name:-}" ] || continue
    name=${name#.}
    name=${name%-wrapped}
    name=${name%-wrapp}
    per[$name]=$((${per[$name]:-0} + 1))
  done <<<"$1"
  for name in "${!per[@]}"; do
    detail+="${detail:+, }$name ${per[$name]}"
  done
  printf '%s' "$detail"
}

check_host_agents() {
  local out rc=0
  if [ -z "$agents_re" ]; then
    signal agents ok "no agent names"
    return 0
  fi
  out=$(pgrep -l -x -- "$agents_re" 2>&1) || rc=$?
  case $rc in
    0) signal agents busy "$(agents_detail "$out")" ;;
    1) signal agents ok none ;;
    *) signal agents busy "pgrep failed: $out" ;;
  esac
}

# Agent sessions in the dev VM, from the status file the VM rewrites every
# 15 s through its share. The VM writes it, so it is read as plain data and
# only when it is a regular file. While the VM runs, a stale or missing
# status counts as busy.
check_vm() {
  local age mtime data agents='' detail='' k v
  [ -n "$vm_unit" ] && [ -n "$vm_status_file" ] || return 0
  if ! systemctl is-active --quiet "$vm_unit" 2>/dev/null; then
    signal vm ok "$vm_name not running"
    return 0
  fi
  if [ ! -f "$vm_status_file" ] || [ -L "$vm_status_file" ]; then
    signal vm busy "$vm_name runs, no status in $vm_status_file"
    return 0
  fi
  mtime=$(stat -c %Y -- "$vm_status_file" 2>/dev/null) || mtime=
  if ! is_number "$mtime"; then
    signal vm busy "$vm_name status unreadable"
    return 0
  fi
  age=$((EPOCHSECONDS - mtime))
  if [ "$age" -gt "$vm_status_max_age" ]; then
    signal vm busy "$vm_name runs, status ${age} s old"
    return 0
  fi
  # A FIFO swapped in after the check above cannot block: timeout.
  data=$(timeout 2 head -c 4096 -- "$vm_status_file" 2>/dev/null) || data=
  while IFS='=' read -r k v; do
    case $k in
      agents) [ -n "$agents" ] || agents=$v ;;
      detail) [ -n "$detail" ] || detail=$v ;;
    esac
  done <<<"$data"
  detail=${detail//[^[:alnum:] ,._-]/}
  if ! is_number "$agents"; then
    signal vm busy "$vm_name status unreadable"
  elif [ "$agents" -gt 0 ]; then
    signal vm busy "$vm_name: ${detail:0:80}"
  else
    signal vm ok "$vm_name: none (status ${age} s old)"
  fi
}

# Someone else's logind sleep block (our own pieces never take one; games
# take `idle`, hypridle a sleep delay).
check_sleep_block() {
  local out who
  if ! out=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager BlockInhibited 2>/dev/null); then
    signal sleep-block ok "BlockInhibited unreadable"
    return 0
  fi
  out=${out#s \"}
  out=${out%\"}
  case ":$out:" in
    *:sleep:*)
      who=$(busctl --json=short call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager ListInhibitors 2>/dev/null |
        jq -r '[.data[0][] | select(.[3] == "block" and (.[0] | split(":") | index("sleep"))) | "\(.[1]) (\(.[2]))"] | join(", ")' 2>/dev/null) || who=
      signal sleep-block busy "${who:-sleep block}"
      ;;
    *) signal sleep-block ok "${out:-none}" ;;
  esac
}

# Running PipeWire output streams (a paused browser stream goes idle), minus
# the ignore list. No PipeWire = nothing playing.
check_audio() {
  local out app bin node names='' name skip
  if ! out=$(timeout 5 pw-dump 2>/dev/null | jq -r '
    .[] | select(.type == "PipeWire:Interface:Node") | .info
    | select(.state == "running" and .props["media.class"] == "Stream/Output/Audio")
    | [.props["application.name"] // "", .props["application.process.binary"] // "",
       .props["node.name"] // ""] | @tsv' 2>/dev/null); then
    signal audio ok "no PipeWire"
    return 0
  fi
  while IFS=$'\t' read -r app bin node; do
    [ -n "$app$bin$node" ] || continue
    skip=0
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      if [ "$name" = "$app" ] || [ "$name" = "$bin" ] || [ "$name" = "$node" ]; then
        skip=1
      fi
    done <<<"$audio_ignore"
    [ "$skip" = 0 ] || continue
    names+="${names:+, }${app:-${bin:-$node}}"
  done <<<"$out"
  if [ -n "$names" ]; then
    signal audio busy "$names"
  else
    signal audio ok none
  fi
}

# Logs the busy reasons when they change (journal, tag power-profile), so
# `journalctl -t power-profile` shows why the PC stayed awake.
log_busy() {
  local now=$1 last=
  if [ -r "$busy_file" ]; then
    IFS= read -r last <"$busy_file" || last=
  fi
  [ "$now" != "$last" ] || return 0
  mkdir -p "$idle_dir"
  printf '%s\n' "$now" >"$busy_file" 2>/dev/null || true
  logger -t power-profile -- "can-sleep: $now" 2>/dev/null || true
}

cmd_can_sleep() {
  local check summary
  case $# in
    0) ;;
    1) [ "$1" = --explain ] || die "usage: power-profile can-sleep [--explain]" ;;
    *) die "usage: power-profile can-sleep [--explain]" ;;
  esac
  [ $# -eq 0 ] || explain=1
  # Cheapest first; without --explain the first busy signal ends the check.
  for check in check_stay_awake check_game check_load check_vm check_ssh \
    check_host_agents check_sleep_block check_audio; do
    "$check"
    [ "$explain" = 1 ] || [ ${#busy_reasons[@]} -eq 0 ] || break
  done
  if [ ${#busy_reasons[@]} -eq 0 ]; then
    if [ "$explain" = 1 ]; then
      echo "=> may sleep"
    else
      log_busy "may sleep"
      echo "may sleep"
    fi
    return 0
  fi
  summary=$(printf '%s; ' "${busy_reasons[@]}")
  summary="busy: ${summary%; }"
  if [ "$explain" = 1 ]; then
    echo "=> $summary"
  else
    log_busy "$summary"
    echo "$summary"
  fi
  exit 1
}

# --- Sleep: suspend ------------------------------------------------------------

cmd_suspend() {
  case ${1:-} in
    --idle)
      [ $# -eq 1 ] || die "usage: power-profile suspend --now|--idle"
      logger -t power-profile -- "suspend: idle, nothing busy" 2>/dev/null || true
      systemctl --no-ask-password suspend
      ;;
    --now)
      [ $# -eq 1 ] || die "usage: power-profile suspend --now|--idle"
      logger -t power-profile -- "suspend: now (menu)" 2>/dev/null || true
      # -i: past logind sleep blocks too (polkit rule suspend-ignore-inhibit).
      if ! systemctl --no-ask-password suspend -i; then
        notify critical "Suspend failed" "See: journalctl -b -u systemd-logind" power-sleep
        die "suspend failed"
      fi
      ;;
    *) die "usage: power-profile suspend --now|--idle" ;;
  esac
}

# Rows: the profiles in menu order (the picked one marked with ●), the
# "Auto (follow games)" toggle, then (with the idle stack) the sleep
# controls: Suspend now, a ● row for an active Stay awake (pick it to turn
# it off), Stay awake 1 h / 2 h / 4 h / until off.
cmd_menu() {
  local current auto profile rows=() actions=() row i choice stay
  [ $# -eq 0 ] || die "usage: power-profile menu"
  command -v rofi >/dev/null 2>&1 || die "rofi not found"
  current=$(picked)
  auto=$(auto_mode)
  for profile in "${profiles[@]}"; do
    if [ "$profile" = "$current" ]; then
      row="● $(label "$profile")"
      [ "$(effective)" = "$profile" ] || row+="  (now: $(effective_label))"
    else
      row="  $(label "$profile")"
    fi
    rows+=("$row")
    actions+=("set $profile")
  done
  rows+=("  Auto (follow games): $auto")
  if [ "$auto" = on ]; then
    actions+=("auto off")
  else
    actions+=("auto on")
  fi
  if [ -n "$idle_on" ]; then
    rows+=("  Suspend now")
    actions+=("suspend --now")
    stay=$(stay_awake_until)
    if [ -n "$stay" ]; then
      rows+=("● Stay awake $(stay_awake_text "$stay")  (pick to turn off)")
      actions+=("stay-awake off")
    fi
    rows+=("  Stay awake 1 h" "  Stay awake 2 h" "  Stay awake 4 h" "  Stay awake until off")
    actions+=("stay-awake 1h" "stay-awake 2h" "stay-awake 4h" "stay-awake on")
  fi

  i=0
  for profile in "${profiles[@]}"; do
    [ "$profile" = "$current" ] && break
    i=$((i + 1))
  done

  # The rofi theme shows 7 rows; show them all so the sleep rows are seen.
  choice=$(printf '%s\n' "${rows[@]}" |
    rofi -dmenu -i -no-custom -format i -p Power -selected-row "$i" \
      -theme-str "listview { lines: ${#rows[@]}; }") || return 0
  case $choice in
    '' | *[!0-9]*) return 0 ;;
  esac
  [ "$choice" -lt "${#actions[@]}" ] || return 0
  # Word-split on purpose: "<command> <argument>".
  # shellcheck disable=SC2086
  set -- ${actions[$choice]}
  case $1 in
    set) cmd_set "$2" ;;
    auto) cmd_auto "$2" ;;
    suspend) cmd_suspend "$2" ;;
    stay-awake) cmd_stay_awake "$2" ;;
  esac
}

command=${1:-status}
[ $# -eq 0 ] || shift
case $command in
  status) status ;;
  get) picked && echo ;;
  set) cmd_set "$@" ;;
  list)
    for p in "${profiles[@]}"; do
      printf '%s\t%s\n' "$p" "$(label "$p")"
    done
    ;;
  auto) cmd_auto "$@" ;;
  sync) cmd_sync "$@" ;;
  menu) cmd_menu "$@" ;;
  display) cmd_display "$@" ;;
  idle) cmd_idle "$@" ;;
  can-sleep) cmd_can_sleep "$@" ;;
  suspend) cmd_suspend "$@" ;;
  stay-awake) cmd_stay_awake "$@" ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
