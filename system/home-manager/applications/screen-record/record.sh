readonly STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/screen-record"
readonly PID_FILE="$STATE_DIR/recorder.pid"
readonly INDICATOR_PID_FILE="$STATE_DIR/indicator.pid"
readonly TAKE_FILE="$STATE_DIR/take"
readonly LOG_FILE="$STATE_DIR/log"

out_dir="${SCREEN_RECORD_DIR:-$HOME/Videos/recordings}"
cam_width="${SCREEN_RECORD_CAM_WIDTH:-480}"
cam_height="${SCREEN_RECORD_CAM_HEIGHT:-270}"
fps="${SCREEN_RECORD_FPS:-60}"
audio="${SCREEN_RECORD_AUDIO:-default_output|default_input}"

monitor_name="screen"
monitor_scale="1"

notify() {
  notify-send -a screen-record -i camera-video "$1" "${2-}" || true
}

running() {
  [ -r "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# Echoes the camera to composite into the recording, empty when there is none.
# The v4l2loopback node wins because `camera-connect` feeds the DSLR into it;
# a plain webcam is the fallback. Both candidates are checked against the real
# /dev node, because gpu-screen-recorder aborts the whole capture when a source
# it was handed cannot be opened.
camera_device() {
  if [ -n "${SCREEN_RECORD_CAMERA:-}" ]; then
    printf '%s' "$SCREEN_RECORD_CAMERA"
    return
  fi

  local device
  for device in /sys/devices/virtual/video4linux/*; do
    [ -c "/dev/${device##*/}" ] || continue
    printf '/dev/%s' "${device##*/}"
    return
  done

  for device in /dev/video*; do
    [ -c "$device" ] || continue
    printf '%s' "$device"
    return
  done
}

# Reads the focused monitor and sizes the indicator to fit behind the camera
# overlay. gpu-screen-recorder composites the camera in physical pixels while
# layer-shell surfaces are placed in logical ones, hence the scale division.
read_monitor() {
  local info
  info="$(hyprctl monitors -j 2>/dev/null | jq -r 'map(select(.focused))[0] | "\(.name) \(.scale)"' 2>/dev/null || true)"

  case "$info" in
    *' '*)
      monitor_name="${info%% *}"
      monitor_scale="${info##* }"
      ;;
  esac

  indicator_width="$(awk -v v="$cam_width" -v s="$monitor_scale" 'BEGIN { if (s + 0 <= 0) s = 1; printf "%d", v / s }')"
  indicator_height="$(awk -v v="$cam_height" -v s="$monitor_scale" 'BEGIN { if (s + 0 <= 0) s = 1; printf "%d", v / s }')"
}

stop_indicator() {
  [ -r "$INDICATOR_PID_FILE" ] || return 0
  kill "$(cat "$INDICATOR_PID_FILE")" 2>/dev/null || true
  rm -f "$INDICATOR_PID_FILE"
}

# Pinned to the monitor being captured and tied to the recorder pid, so the pill
# cannot outlive a capture that dies on its own.
start_indicator() {
  stop_indicator
  nohup screen-record-indicator \
    --monitor "$monitor_name" \
    --watch-pid "$1" \
    --max-width "$indicator_width" \
    --max-height "$indicator_height" \
    >/dev/null 2>&1 &
  echo $! >"$INDICATOR_PID_FILE"
}

cmd_start() {
  if running; then
    notify "Already recording" "$(cat "$TAKE_FILE" 2>/dev/null || true)"
    return 0
  fi

  if ! command -v gpu-screen-recorder >/dev/null; then
    notify "Cannot record" "gpu-screen-recorder is not on PATH"
    return 1
  fi

  mkdir -p "$STATE_DIR" "$out_dir"
  read_monitor

  local take
  take="$out_dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

  local camera
  camera="$(camera_device)"

  local capture="monitor:$monitor_name"
  if [ -n "$camera" ]; then
    capture="$capture|v4l2:$camera;width=$cam_width;height=$cam_height;halign=end;valign=end"
  fi

  nohup gpu-screen-recorder \
    -w "$capture" \
    -f "$fps" \
    -a "$audio" \
    -k h264 \
    -ac aac \
    -q very_high \
    -fm cfr \
    -cr limited \
    -cursor yes \
    -v no \
    -o "$take" \
    >"$LOG_FILE" 2>&1 &
  local recorder_pid=$!
  echo "$recorder_pid" >"$PID_FILE"
  printf '%s\n' "$take" >"$TAKE_FILE"

  sleep 1
  if ! running; then
    rm -f "$PID_FILE"
    notify "Recording failed" "$(tail -n 3 "$LOG_FILE" 2>/dev/null || true)"
    return 1
  fi

  start_indicator "$recorder_pid"

  if [ -n "$camera" ]; then
    notify "Recording started" "$monitor_name + facecam ($camera)"
  else
    notify "Recording started" "$monitor_name, no camera found"
  fi
}

cmd_stop() {
  stop_indicator

  if ! running; then
    rm -f "$PID_FILE"
    notify "Not recording"
    return 0
  fi

  local pid
  pid="$(cat "$PID_FILE")"

  # SIGINT is what makes gpu-screen-recorder finalise the mp4 container, so the
  # file is only playable once the process is actually gone.
  kill -INT "$pid" 2>/dev/null || true

  local waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 150 ]; do
    sleep 0.1
    waited=$((waited + 1))
  done

  # The pid file stays while the recorder does, so `start` cannot launch a
  # second capture that fights this one for the camera and the encoder.
  if kill -0 "$pid" 2>/dev/null; then
    notify "Recording still finalising" "$(cat "$TAKE_FILE" 2>/dev/null || true)"
    return 1
  fi

  rm -f "$PID_FILE"
  notify "Recording saved" "$(cat "$TAKE_FILE" 2>/dev/null || true)"
}

cmd_restart() {
  cmd_stop
  cmd_start
}

cmd_status() {
  if running; then
    echo "recording: $(cat "$TAKE_FILE" 2>/dev/null || true)"
  else
    echo "idle"
  fi
}

cmd_devices() {
  echo "cameras:"
  gpu-screen-recorder --list-v4l2-devices || true
  echo
  echo "audio devices:"
  gpu-screen-recorder --list-audio-devices || true
}

case "${1-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_restart ;;
  status) cmd_status ;;
  devices) cmd_devices ;;
  *)
    echo "usage: screen-record start|stop|restart|status|devices" >&2
    exit 1
    ;;
esac
