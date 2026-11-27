# wifi-menu: the top bar's Wi-Fi menu, a rofi pick list over NetworkManager.
# Rows: the networks in range, strongest first (the one in use marked ●,
# first), then Rescan and Turn Wi-Fi off; with Wi-Fi off, only Turn Wi-Fi
# on. Picking the network in use disconnects it; another one joins it: a
# saved network straight away, a new secured one after asking for its
# password. Every result shows a notification. Rescanning and turning Wi-Fi
# on reopen the menu.

notify() {
  notify-send -a Wi-Fi "$@" 2>/dev/null || true
}

theme="window { location: north east; anchor: north east; x-offset: -10px; y-offset: 10px; }"

# rofi under the top bar's right end; prints the picked row's index.
pick() {
  local prompt=$1
  shift
  printf '%s\n' "$@" |
    rofi -dmenu -i -no-custom -format i -p "$prompt" \
      -theme-str "$theme listview { lines: $(($# < 12 ? $# : 12)); }"
}

# The rofi theme hides the input bar; the password prompt shows it instead
# of the list.
ask_password() {
  rofi -dmenu -password -p "Password for $1" \
    -theme-str "$theme inputbar { enabled: true; children: [ prompt, entry ]; } listview { enabled: false; } mode-switcher { enabled: false; } window { height: 4em; }" \
    </dev/null
}

wifi_device() {
  nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }'
}

# Networks in range as "<in use 1|0>\t<signal>\t<security>\t<ssid>", the one
# in use first, then strongest first, one row per SSID. nmcli -t escapes ':'
# and '\' in values; the SSID is the last field, so only it can hold them.
networks() {
  local line in_use signal security ssid
  nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null |
    while IFS= read -r line; do
      in_use=${line%%:*}
      line=${line#*:}
      signal=${line%%:*}
      line=${line#*:}
      security=${line%%:*}
      ssid=${line#*:}
      ssid=${ssid//\\:/:}
      ssid=${ssid//\\\\/\\}
      [ -n "$ssid" ] || continue
      [ "$security" != "--" ] || security=
      printf '%s\t%s\t%s\t%s\n' "$([ "$in_use" = "*" ] && echo 1 || echo 0)" "$signal" "$security" "$ssid"
    done |
    sort -t $'\t' -k1,1nr -k2,2nr |
    awk -F '\t' '!seen[$4]++'
}

# nmcli -g escapes ':' and '\' like -t.
unescape() {
  sed 's/\\:/:/g; s/\\\\/\\/g'
}

# The saved Wi-Fi profile for an SSID, by its SSID rather than its name (a
# profile can be renamed, or named "<ssid> 1"); prints the profile's name.
saved() {
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$(nmcli -g 802-11-wireless.ssid connection show id "$name" 2>/dev/null | unescape)" = "$1" ]; then
      printf '%s\n' "$name"
      return 0
    fi
  done < <(nmcli -g NAME,TYPE connection show 2>/dev/null | sed -n 's/:802-11-wireless$//p' | unescape)
  return 1
}

join() {
  local ssid=$1 security=$2 password out profile
  if profile=$(saved "$ssid"); then
    if out=$(nmcli --wait 30 connection up id "$profile" 2>&1); then
      notify "Connected to $ssid"
    else
      notify -u critical "Could not join $ssid" "$(printf '%s\n' "$out" | tail -n 1)"
    fi
    return 0
  fi
  if [ -n "$security" ]; then
    password=$(ask_password "$ssid") || return 0
    [ -n "$password" ] || return 0
    out=$(nmcli --wait 30 device wifi connect "$ssid" password "$password" 2>&1) && {
      notify "Connected to $ssid"
      return 0
    }
  else
    out=$(nmcli --wait 30 device wifi connect "$ssid" 2>&1) && {
      notify "Connected to $ssid"
      return 0
    }
  fi
  # A failed first join leaves a profile behind (with a wrong password, say);
  # drop it so the next try asks again.
  nmcli connection delete id "$ssid" >/dev/null 2>&1 || true
  notify -u critical "Could not join $ssid" "$(printf '%s\n' "$out" | tail -n 1)"
}

menu() {
  local device rows=() actions=() ssids=() securities=() in_use signal security ssid choice active
  device=$(wifi_device)
  if [ -z "$device" ]; then
    notify "Wi-Fi" "No Wi-Fi device found."
    return 0
  fi

  if [ "$(nmcli radio wifi 2>/dev/null)" != enabled ]; then
    rows=("  Turn Wi-Fi on")
    actions=("radio-on")
    ssids=("")
    securities=("")
  else
    while IFS=$'\t' read -r in_use signal security ssid; do
      if [ "$in_use" = 1 ]; then
        rows+=("● $ssid  (connected, $signal%)")
        actions+=("disconnect")
      else
        rows+=("  $ssid  ($signal%${security:+, secured})")
        actions+=("join")
      fi
      ssids+=("$ssid")
      securities+=("$security")
    done < <(networks)
    rows+=("  Rescan" "  Turn Wi-Fi off")
    actions+=("rescan" "radio-off")
    ssids+=("" "")
    securities+=("" "")
  fi

  choice=$(pick Wi-Fi "${rows[@]}") || return 0
  case $choice in
    '' | *[!0-9]*) return 0 ;;
  esac
  [ "$choice" -lt "${#actions[@]}" ] || return 0
  case ${actions[$choice]} in
    radio-on)
      nmcli radio wifi on || notify -u critical "Could not turn Wi-Fi on"
      menu
      ;;
    radio-off) nmcli radio wifi off && notify "Wi-Fi off" ;;
    rescan)
      notify "Wi-Fi" "Scanning…"
      nmcli device wifi rescan >/dev/null 2>&1 || true
      menu
      ;;
    disconnect)
      active=$(nmcli -g GENERAL.CONNECTION device show "$device" 2>/dev/null)
      if [ -n "$active" ] && nmcli connection down id "$active" >/dev/null 2>&1; then
        notify "Disconnected from $active"
      else
        notify -u critical "Could not disconnect"
      fi
      ;;
    join) join "${ssids[$choice]}" "${securities[$choice]}" ;;
  esac
}

[ $# -eq 0 ] || {
  echo "usage: wifi-menu" >&2
  exit 2
}
menu
