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
                  profile wants now (idle screen-off hook)
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

# notify <urgency> <summary> <body>; best effort. Also works from a systemd
# user service (session bus at $XDG_RUNTIME_DIR/bus).
notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$runtime_dir/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"
  fi
  # The stack tag makes dunst replace the previous power-profile popup.
  timeout 5 notify-send --app-name=power-profile --urgency="$1" \
    --hint=string:x-dunst-stack-tag:power-profile "$2" "$3" \
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

# Rows: the profiles in menu order (the picked one marked with ●), then the
# "Auto (follow games)" toggle.
cmd_menu() {
  local current auto profile rows=() row i choice
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
  done
  rows+=("  Auto (follow games): $auto")

  i=0
  for profile in "${profiles[@]}"; do
    [ "$profile" = "$current" ] && break
    i=$((i + 1))
  done

  choice=$(printf '%s\n' "${rows[@]}" |
    rofi -dmenu -i -no-custom -format i -p Power -selected-row "$i") || return 0
  case $choice in
    '' | *[!0-9]*) return 0 ;;
  esac
  if [ "$choice" -lt "${#profiles[@]}" ]; then
    cmd_set "${profiles[$choice]}"
  elif [ "$choice" -eq "${#profiles[@]}" ]; then
    if [ "$auto" = on ]; then
      cmd_auto off
    else
      cmd_auto on
    fi
  fi
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
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
