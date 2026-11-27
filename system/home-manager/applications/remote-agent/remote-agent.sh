# remote-agent: the remote-agent app and its tailnet connection (doc/adr/0003).
#
# The desktop reaches the tailnet only through a user-level tailscaled in
# userspace networking mode (the remote-agent-tailscaled user unit): no
# network interface, no routes, no DNS changes, just a SOCKS5 proxy on
# 127.0.0.1. The app is a Chrome app window with its own profile pointed at
# that proxy, so it is the only thing that reaches the tailnet.
#
# Commands:
#   open        connect when not connected (up to the connect timeout), then
#               open the app window; a failed connect still opens the window
#   status      print the connection state (below)
#   bar         the top bar's Tailscale item, as Waybar JSON
#   click       the bar item's click: disconnect when connected, connect when
#               disconnected or failed, start the sign-in when it needs one
#   connect     connect; a failure leaves the state failed and notifies
#   disconnect  disconnect
#   login       start the tailnet sign-in and open its page in the browser
#
# States: connected, disconnected, connecting, needs-sign-in, failed. The bar
# shows needs-sign-in and failed as one state.
#
# Set by the Nix wrapper: REMOTE_AGENT_URL, REMOTE_AGENT_PROXY,
# REMOTE_AGENT_HOSTNAME, REMOTE_AGENT_CONNECT_TIMEOUT (seconds),
# REMOTE_AGENT_BAR_SIGNAL (Waybar's signal for the item, SIGRTMIN+n).

url=${REMOTE_AGENT_URL:?}
proxy=${REMOTE_AGENT_PROXY:?}
node_name=${REMOTE_AGENT_HOSTNAME:?}
connect_timeout=${REMOTE_AGENT_CONNECT_TIMEOUT:-15}
bar_signal=${REMOTE_AGENT_BAR_SIGNAL:-}

runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
socket=$runtime_dir/tailscale/tailscaled.sock
state_dir=$runtime_dir/remote-agent
# A connect in progress: holds the PID of the process running it.
connecting_file=$state_dir/connecting
# The last connect failed: holds the reason. Cleared by the next connect, a
# disconnect, or the connection coming up.
failed_file=$state_dir/failed
lock_file=$state_dir/lock
login_log=$state_dir/login.log
profile_dir=${XDG_DATA_HOME:-$HOME/.local/share}/remote-agent/chrome

# Every `up` names every setting, and --reset drops any other, so a setting
# changed by hand cannot make `up` refuse to run.
up_flags=(--reset --shields-up "--hostname=$node_name")

die() {
  printf 'remote-agent: %s\n' "$*" >&2
  exit 1
}

ts() {
  tailscale --socket="$socket" "$@"
}

# BackendState of the user tailscaled (Running, Stopped, Starting,
# NeedsLogin, NeedsMachineAuth, NoState), or Unreachable when it does not
# answer.
backend_state() {
  local json state
  json=$(ts status --json 2>/dev/null) || true
  state=$(jq -r '.BackendState // empty' <<<"$json" 2>/dev/null) || true
  printf '%s\n' "${state:-Unreachable}"
}

connect_running() {
  local pid
  [ -f "$connecting_file" ] || return 1
  pid=$(cat "$connecting_file" 2>/dev/null) || return 1
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

current_state() {
  local backend
  backend=$(backend_state)
  if [ "$backend" = Running ]; then
    rm -f "$failed_file"
    echo connected
    return
  fi
  if connect_running; then
    echo connecting
    return
  fi
  # Before a failure, so a click on a signed-out desktop signs in rather
  # than retrying the connect.
  case $backend in
    NeedsLogin | NeedsMachineAuth)
      echo needs-sign-in
      return
      ;;
  esac
  if [ -f "$failed_file" ]; then
    echo failed
    return
  fi
  case $backend in
    Starting) echo connecting ;;
    Stopped) echo disconnected ;;
    *) echo failed ;;
  esac
}

refresh_bar() {
  [ -n "$bar_signal" ] || return 0
  pkill "-RTMIN+$bar_signal" waybar 2>/dev/null || true
}

notify() {
  notify-send -a "Remote agent" "$@" 2>/dev/null || true
}

fail() {
  printf '%s\n' "$1" >"$failed_file"
  rm -f "$connecting_file"
  notify -u critical "Tailscale did not connect" "$1"
  refresh_bar
  return 1
}

cmd_connect() {
  local backend out
  mkdir -p "$state_dir"
  # One connect at a time; a second one waits and then finds it connected.
  exec 9>"$lock_file"
  # Returns rather than exits, so `open` still opens the window.
  if ! flock -w $((connect_timeout + 10)) 9; then
    printf 'remote-agent: another connect is still running\n' >&2
    return 1
  fi
  if [ "$(backend_state)" = Running ]; then
    rm -f "$failed_file"
    refresh_bar
    return 0
  fi
  rm -f "$failed_file"
  echo "$$" >"$connecting_file"
  refresh_bar

  backend=$(backend_state)
  case $backend in
    Unreachable)
      fail "The remote-agent tailscaled is not running (systemctl --user status remote-agent-tailscaled)."
      return
      ;;
    NeedsLogin | NeedsMachineAuth)
      fail "This desktop is not signed into the tailnet. Click the Tailscale item in the top bar to sign in."
      return
      ;;
  esac

  if ! out=$(ts up "${up_flags[@]}" --timeout="${connect_timeout}s" 2>&1); then
    out=$(printf '%s\n' "$out" | sed '/^[[:space:]]*$/d' | tail -n 1)
    fail "${out:-tailscale up failed}"
    return
  fi
  if [ "$(backend_state)" != Running ]; then
    fail "Tailscale did not come up within ${connect_timeout} s."
    return
  fi
  rm -f "$connecting_file"
  refresh_bar
}

cmd_disconnect() {
  mkdir -p "$state_dir"
  rm -f "$failed_file" "$connecting_file"
  ts down || die "tailscale down failed"
  refresh_bar
}

# Starts `tailscale up` in the background (it waits until the sign-in is
# done) and opens the login URL it reports. The login page is public, so the
# default browser opens it without the tailnet.
cmd_login() {
  local auth_url='' i
  mkdir -p "$state_dir"
  rm -f "$failed_file"
  setsid -f tailscale --socket="$socket" up "${up_flags[@]}" --timeout=10m \
    >"$login_log" 2>&1 </dev/null
  for ((i = 0; i < 30; i++)); do
    auth_url=$(ts status --json 2>/dev/null | jq -r '.AuthURL // empty' 2>/dev/null) || true
    [ -n "$auth_url" ] && break
    [ "$(backend_state)" = Running ] && break
    sleep 0.5
  done
  if [ -n "$auth_url" ]; then
    xdg-open "$auth_url" >/dev/null 2>&1 || notify "Tailscale sign-in" "Open $auth_url to sign in."
  elif [ "$(backend_state)" != Running ]; then
    fail "Tailscale did not return a sign-in page (see $login_log)."
    return
  fi
  refresh_bar
}

cmd_bar() {
  local state text tooltip class
  state=$(current_state)
  case $state in
    connected)
      text="󰖂"
      class=connected
      tooltip="Tailscale: connected (remote-agent app only)"$'\n'"Click to disconnect"
      ;;
    disconnected)
      text="󰖂 off"
      class=disconnected
      tooltip="Tailscale: disconnected"$'\n'"Click to connect"
      ;;
    connecting)
      text="󰖂 …"
      class=connecting
      tooltip="Tailscale: connecting…"
      ;;
    needs-sign-in)
      text="󰖂 !"
      class=failed
      tooltip="Tailscale: needs sign-in"$'\n'"Click to sign in"
      ;;
    *)
      text="󰖂 !"
      class=failed
      tooltip="Tailscale: failed"
      if [ -s "$failed_file" ]; then
        tooltip+=$'\n'"$(cat "$failed_file")"
      fi
      tooltip+=$'\n'"Click to connect"
      ;;
  esac
  jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" --arg alt "$state" \
    '{text: $text, tooltip: $tooltip, class: $class, alt: $alt}'
}

cmd_click() {
  case $(current_state) in
    connected) cmd_disconnect ;;
    disconnected | failed) cmd_connect ;;
    needs-sign-in) cmd_login ;;
    connecting) refresh_bar ;;
  esac
}

cmd_open() {
  if [ "$(current_state)" != connected ]; then
    # A failed connect has notified; the window opens anyway and loads once
    # the bar connects.
    cmd_connect || true
  fi
  mkdir -p "$profile_dir"
  # Its own profile: Chrome would hand a window for the everyday profile to
  # the running browser and drop --proxy-server. socks5:// makes Chrome
  # resolve host names through the proxy, so MagicDNS names resolve. The
  # connect lock (fd 9) stays here, not with Chrome.
  exec 9>&-
  exec google-chrome-stable \
    --user-data-dir="$profile_dir" \
    --proxy-server="$proxy" \
    --no-first-run \
    --no-default-browser-check \
    --class=remote-agent \
    --app="$url"
}

usage() {
  echo "usage: remote-agent open|status|bar|click|connect|disconnect|login" >&2
  exit 2
}

command=${1:-}
[ $# -eq 0 ] || shift
[ $# -eq 0 ] || usage
case $command in
  open) cmd_open ;;
  status) current_state ;;
  bar) cmd_bar ;;
  click) cmd_click ;;
  connect) cmd_connect ;;
  disconnect) cmd_disconnect ;;
  login) cmd_login ;;
  *) usage ;;
esac
