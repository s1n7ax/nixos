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
# Environment (set by the NixOS module; tests point it at a fake tree):
#   POWER_PROFILE_STATE_FILE  persisted state
#   POWER_PROFILE_RUN_DIR     the root side's applied record
#   POWER_PROFILE_DEFAULT     profile used while nothing is picked
#   POWER_PROFILE_GAMES_FILE  running games, one per line (game watcher);
#                             default $XDG_RUNTIME_DIR/power-profile/games

state_file=${POWER_PROFILE_STATE_FILE:-/var/lib/power-profile/state}
state_dir=${state_file%/*}
run_dir=${POWER_PROFILE_RUN_DIR:-/run/power-profile}
applied_file=$run_dir/applied
default_profile=${POWER_PROFILE_DEFAULT:-disabled}
games_file=${POWER_PROFILE_GAMES_FILE:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/power-profile/games}

# Keep in sync with features.hardware.power-profile.profiles and
# power-profile-ctl.sh.
profiles=(strict short-boosts full-speed-heavy disabled full-power)

die() {
  echo "power-profile: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: power-profile [command]

Commands:
  status          picked profile, auto, game, effective and applied (default)
  get             print the picked profile
  set <profile>   pick a profile, save it and apply it now
  list            list profiles as "<profile><TAB><label>"
  auto [on|off]   print or set "Auto (follow games)"
  sync            apply the effective profile if it is not applied yet
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
    die "applying $1 failed; see: journalctl -b -u $unit"
  fi
}

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
}

cmd_set() {
  [ $# -eq 1 ] || die "usage: power-profile set <profile>"
  valid_profile "$1" || die "unknown profile '$1' (one of: ${profiles[*]})"
  lock
  write_state "$1" "$(auto_mode)"
  apply "$(effective)"
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
  sync_applied
  status
}

sync_applied() {
  local want
  want=$(effective)
  if [ "$(read_kv "$applied_file" profile)" != "$want" ] ||
    [ "$(read_kv "$applied_file" result)" != ok ]; then
    apply "$want"
  fi
}

cmd_sync() {
  [ $# -eq 0 ] || die "usage: power-profile sync"
  lock
  sync_applied
  status
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
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
