# bt-reconnect: connect every paired Bluetooth audio device (headphones,
# headsets, speakers) that is not connected, and mark it trusted so it may
# also connect by itself later. Runs after bluetooth starts and after every
# resume; gives up quietly after $BT_RECONNECT_TIMEOUT seconds (device off
# or out of range). Phones never match: they offer the gateway side of the
# audio profiles, not these.

timeout_s=${BT_RECONNECT_TIMEOUT:-90}
# Audio Sink, Handsfree, Headset
audio_uuids='0000110b-|0000111e-|00001108-'

powered() { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }

audio_devices() {
  local mac
  bluetoothctl devices Paired 2>/dev/null | awk '$1 == "Device" { print $2 }' |
    while read -r mac; do
      if bluetoothctl info "$mac" 2>/dev/null | grep -Eqi "UUID: .*\((${audio_uuids})"; then
        echo "$mac"
      fi
    done
}

info_has() { bluetoothctl info "$1" 2>/dev/null | grep -q "$2"; }

deadline=$((SECONDS + timeout_s))

until powered; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "adapter not powered after ${timeout_s}s; giving up"
    exit 0
  fi
  sleep 1
done

mapfile -t devices < <(audio_devices)
if [ "${#devices[@]}" -eq 0 ]; then
  echo "no paired audio devices"
  exit 0
fi

for mac in "${devices[@]}"; do
  if ! info_has "$mac" 'Trusted: yes'; then
    bluetoothctl trust "$mac" >/dev/null 2>&1 && echo "trusted $mac"
  fi
done

while :; do
  pending=()
  for mac in "${devices[@]}"; do
    info_has "$mac" 'Connected: yes' && continue
    timeout 15 bluetoothctl connect "$mac" >/dev/null 2>&1 || true
    if info_has "$mac" 'Connected: yes'; then
      echo "connected $mac"
    else
      pending+=("$mac")
    fi
  done
  [ "${#pending[@]}" -eq 0 ] && exit 0
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "not connected after ${timeout_s}s (off or out of range): ${pending[*]}"
    exit 0
  fi
  sleep 5
done
