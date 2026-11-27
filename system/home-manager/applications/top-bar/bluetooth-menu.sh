# bluetooth-menu: the top bar's Bluetooth menu, a rofi pick list. Rows: the
# devices BlueZ knows (connected ones marked ●, first), then Scan for new
# devices and Turn Bluetooth off; with Bluetooth off, only Turn Bluetooth
# on. Picking a connected device disconnects it, a paired one connects it,
# and a new one (found by a scan) pairs, trusts and connects it. Every
# result shows a notification. Scanning and turning Bluetooth on reopen the
# menu.

scan_seconds=10

notify() {
  notify-send -a Bluetooth "$@" 2>/dev/null || true
}

# rofi under the top bar's right end; prints the picked row's index.
pick() {
  local prompt=$1
  shift
  printf '%s\n' "$@" |
    rofi -dmenu -i -no-custom -format i -p "$prompt" \
      -theme-str "window { location: north east; anchor: north east; x-offset: -10px; y-offset: 10px; } listview { lines: $(($# < 12 ? $# : 12)); }"
}

# The devices `bluetoothctl info` reports a "<key>: yes" for.
has() {
  bluetoothctl info "$1" 2>/dev/null | grep -q "^[[:space:]]*$2: yes"
}

# Runs one bluetoothctl action and notifies with its outcome.
run() {
  local title=$1 out
  shift
  if out=$(bluetoothctl "$@" 2>&1); then
    notify "$title"
  else
    notify -u critical "$title failed" "$(printf '%s\n' "$out" | tail -n 1)"
    return 1
  fi
}

menu() {
  local rows=() actions=() names=() connected=() paired=() new=() entry mac name choice
  if ! bluetoothctl show >/dev/null 2>&1; then
    notify -u critical "Bluetooth" "No Bluetooth controller found."
    return 0
  fi

  if ! bluetoothctl show | grep -q '^[[:space:]]*Powered: yes'; then
    rows=("  Turn Bluetooth on")
    actions=("power-on")
    names=("")
  else
    while read -r _ mac name; do
      [ -n "$mac" ] || continue
      if has "$mac" Connected; then
        connected+=("$mac $name")
      elif has "$mac" Paired; then
        paired+=("$mac $name")
      else
        new+=("$mac $name")
      fi
    done < <(bluetoothctl devices 2>/dev/null | grep '^Device ' | sort -k3)

    for entry in "${connected[@]}"; do
      rows+=("● ${entry#* }  (connected)")
      actions+=("disconnect ${entry%% *}")
      names+=("${entry#* }")
    done
    for entry in "${paired[@]}"; do
      rows+=("  ${entry#* }")
      actions+=("connect ${entry%% *}")
      names+=("${entry#* }")
    done
    for entry in "${new[@]}"; do
      rows+=("  ${entry#* }  (new, pick to pair)")
      actions+=("pair ${entry%% *}")
      names+=("${entry#* }")
    done
    rows+=("  Scan for new devices" "  Turn Bluetooth off")
    actions+=("scan" "power-off")
    names+=("" "")
  fi

  choice=$(pick Bluetooth "${rows[@]}") || return 0
  case $choice in
    '' | *[!0-9]*) return 0 ;;
  esac
  [ "$choice" -lt "${#actions[@]}" ] || return 0
  # Word-split on purpose: "<action> <address>".
  # shellcheck disable=SC2086
  set -- ${actions[$choice]}
  name=${names[$choice]}
  case $1 in
    power-on)
      run "Bluetooth on" power on || return 0
      menu
      ;;
    power-off) run "Bluetooth off" power off || true ;;
    scan)
      notify "Bluetooth" "Scanning for new devices for ${scan_seconds} s…"
      bluetoothctl --timeout "$scan_seconds" scan on >/dev/null 2>&1 || true
      menu
      ;;
    connect) run "Connected $name" connect "$2" || true ;;
    disconnect) run "Disconnected $name" disconnect "$2" || true ;;
    pair)
      run "Paired $name" pair "$2" || return 0
      bluetoothctl trust "$2" >/dev/null 2>&1 || true
      run "Connected $name" connect "$2" || true
      ;;
  esac
}

[ $# -eq 0 ] || {
  echo "usage: bluetooth-menu" >&2
  exit 2
}
menu
