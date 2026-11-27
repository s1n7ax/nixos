# Drives remote-agent through every state and command against the fakes in
# check.nix.
set -euo pipefail

root=$(mktemp -d)
export HOME=$root/home XDG_RUNTIME_DIR=$root/run XDG_DATA_HOME=$root/data FAKE_DIR=$root/fake
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$FAKE_DIR"

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# Starts a case: a fresh fake with the given BackendState and no app state.
given() {
  rm -rf "${FAKE_DIR:?}"/* "$XDG_RUNTIME_DIR/remote-agent"
  echo "$1" >"$FAKE_DIR/state"
}

expect_state() {
  local got
  got=$(remote-agent status)
  [ "$got" = "$1" ] || fail "$2: status is '$got', want '$1'"
}

expect_bar_class() {
  local got
  got=$(remote-agent bar | jq -r .class)
  [ "$got" = "$1" ] || fail "$2: bar class is '$got', want '$1'"
}

calls() {
  cat "$FAKE_DIR/calls" 2>/dev/null || true
}

# --- States -----------------------------------------------------------------

given Running
expect_state connected "Running"
expect_bar_class connected "Running"

given Stopped
expect_state disconnected "Stopped"
expect_bar_class disconnected "Stopped"

given Starting
expect_state connecting "Starting"
expect_bar_class connecting "Starting"

given NeedsLogin
expect_state needs-sign-in "NeedsLogin"
expect_bar_class failed "NeedsLogin (shown as needs sign-in or failed)"

given Unreachable
expect_state failed "daemon not running"
expect_bar_class failed "daemon not running"

remote-agent bar | jq -e 'has("text") and has("tooltip") and has("class") and has("alt")' >/dev/null ||
  fail "bar output is not Waybar JSON with text, tooltip, class, alt"

# --- Click ------------------------------------------------------------------

given Stopped
remote-agent click
expect_state connected "click while disconnected"
calls | grep -qx -- "--socket=$XDG_RUNTIME_DIR/tailscale/tailscaled.sock up --reset --shields-up --hostname=desktop --timeout=2s" ||
  fail "click while disconnected: up not called with shields up and the node name: $(calls)"

given Running
remote-agent click
expect_state disconnected "click while connected"
calls | grep -q ' down$' || fail "click while connected: down not called"

given Starting
remote-agent click
calls | grep -Eq ' (up|down)( |$)' && fail "click while connecting: changed the connection"

# --- A failed connect -------------------------------------------------------

given Stopped
touch "$FAKE_DIR/up-fails"
if remote-agent connect; then
  fail "connect without internet: exit 0"
fi
expect_state failed "failed connect"
expect_bar_class failed "failed connect"
grep -q "Tailscale did not connect" "$FAKE_DIR/notify" 2>/dev/null ||
  fail "failed connect: no notification"
grep -q "no internet" "$FAKE_DIR/notify" 2>/dev/null ||
  fail "failed connect: notification lacks the reason"
remote-agent bar | jq -r .tooltip | grep -q "no internet" ||
  fail "failed connect: tooltip lacks the reason"

rm "$FAKE_DIR/up-fails"
remote-agent click
expect_state connected "click after a failed connect"

# A failure that the daemon got over by itself does not stick.
given Stopped
touch "$FAKE_DIR/up-fails"
remote-agent connect || true
echo Running >"$FAKE_DIR/state"
expect_state connected "failed connect, then Running"
echo Stopped >"$FAKE_DIR/state"
expect_state disconnected "failed connect, Running, then Stopped"

given Unreachable
remote-agent connect && fail "connect with the daemon down: exit 0"
grep -q "remote-agent-tailscaled" "$FAKE_DIR/notify" 2>/dev/null ||
  fail "connect with the daemon down: notification does not name the unit"

given NeedsLogin
remote-agent connect && fail "connect while signed out: exit 0"
expect_state needs-sign-in "connect while signed out"
expect_bar_class failed "connect while signed out"
grep -q "sign in" "$FAKE_DIR/notify" 2>/dev/null ||
  fail "connect while signed out: notification does not say to sign in"
calls | grep -q ' up ' && fail "connect while signed out: ran up (it would wait for a sign-in)"

# The bar's click after that starts the sign-in rather than another connect.
remote-agent click
[ "$(cat "$FAKE_DIR/opened" 2>/dev/null)" = https://login.tailscale.com/a/fake ] ||
  fail "click after a signed-out connect: login page not opened"

# Disconnecting clears a failure.
given Stopped
touch "$FAKE_DIR/up-fails"
remote-agent connect || true
remote-agent disconnect
expect_state disconnected "disconnect after a failed connect"

# --- Sign-in ----------------------------------------------------------------

given NeedsLogin
remote-agent click
[ "$(cat "$FAKE_DIR/opened" 2>/dev/null)" = https://login.tailscale.com/a/fake ] ||
  fail "click while signed out: login page not opened"

# --- The app ----------------------------------------------------------------

given Stopped
remote-agent open
calls | grep -q ' up ' || fail "open while disconnected: did not connect"
expect_state connected "open while disconnected"
chrome=$(cat "$FAKE_DIR/chrome" 2>/dev/null || true)
for arg in \
  "--app=https://remote-agent.example.ts.net" \
  "--proxy-server=socks5://127.0.0.1:1055" \
  "--user-data-dir=$XDG_DATA_HOME/remote-agent/chrome"; do
  grep -qxF -- "$arg" <<<"$chrome" || fail "open: Chrome not started with $arg: $chrome"
done

given Running
remote-agent open
calls | grep -Eq ' (up|down)( |$)' && fail "open while connected: changed the connection"
[ -s "$FAKE_DIR/chrome" ] || fail "open while connected: Chrome not started"

given Stopped
touch "$FAKE_DIR/up-fails"
remote-agent open
[ -s "$FAKE_DIR/chrome" ] || fail "open with a failed connect: Chrome not started"
grep -q "Tailscale did not connect" "$FAKE_DIR/notify" 2>/dev/null ||
  fail "open with a failed connect: no notification"

# --- Usage ------------------------------------------------------------------

remote-agent nonsense 2>/dev/null && fail "unknown command: exit 0"
remote-agent status extra 2>/dev/null && fail "extra argument: exit 0"

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "remote-agent: all cases pass"
