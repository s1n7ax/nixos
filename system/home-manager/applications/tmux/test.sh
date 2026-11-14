# Tests tmux-workspace against a real tmux server in a throwaway HOME. A fake
# ssh runs the remote command locally, with $t/remote/<host> as the host's
# home. With -t, like the real one, it outlives a lost terminal: only a signal
# or the remote shell's exit ends it. A fake shell logs where it started and
# exits with the code typed into it. Run by the flake check `tmux-workspace`
# (in the Nix sandbox).
#
# Workspace folders are literal "~/<path>" strings, and wait_for evaluates its
# condition each time it polls, hence the two shellcheck exceptions.
# shellcheck disable=SC2016,SC2088
set -euo pipefail

t=$(mktemp -d)
trap 'tmux kill-server 2>/dev/null || true; rm -rf "$t"' EXIT

export HOME=$t/home XDG_STATE_HOME=$t/state TMUX_TMPDIR=$t/sock
export PATH=$t/bin:$PATH
unset TMUX TMUX_PANE
mkdir -p "$HOME" "$TMUX_TMPDIR" "$t/bin" "$t/remote/dev" "$t/remote/homelab"
state=$XDG_STATE_HOME/tmux-workspace/main
shells=$t/shells.log
touch "$shells"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}
pass() {
  echo "ok: $*"
}

cat >"$t/bin/fakeshell" <<EOF
#!$(command -v bash)
echo "\${WS_WHERE:-local} \$PWD" >>"$shells"
read -r code
exit "\${code:-0}"
EOF

cat >"$t/bin/ssh" <<EOF
#!$(command -v bash)
tty=
while [[ \$1 == -* ]]; do
  [[ \$1 == -t ]] && tty=1
  [[ \$1 == -o ]] && shift
  shift
done
host=\$1
shift
if [[ -e "$t/down-\$host" ]]; then
  echo "ssh: connect to host \$host: Connection refused" >&2
  exit 255
fi
export HOME="$t/remote/\$host" WS_WHERE=\$host SHELL="$t/bin/fakeshell"
cd "\$HOME"
if [[ -z \$tty ]]; then
  exec sh -c "\$*"
fi
in="$t/ssh-in.\$\$"
mkfifo "\$in"
exec 3<>"\$in"
cat <&0 >"\$in" &
sh -c "\$*" <"\$in" &
remote=\$!
trap 'kill \$remote; exit 255' HUP TERM
wait \$remote
EOF
chmod +x "$t/bin/fakeshell" "$t/bin/ssh"

cat >"$HOME/.tmux.conf" <<EOF
set -g base-index 1
set -g renumber-windows on
set -g default-shell "$t/bin/fakeshell"
EOF

wait_for() {
  local tries=100
  while ((tries--)); do
    if eval "$1"; then
      return 0
    fi
    sleep 0.1
  done
  fail "timed out waiting for: $2"
}

names() {
  tmux list-windows -t =main -F '#{window_name}' | paste -sd ' '
}

window_id() {
  tmux list-windows -t =main -F '#{window_id} #{window_name}' | awk -v n="$1" '$2 == n { print $1 }'
}

saved() {
  paste -sd ' ' "$state" | tr '\t' ':'
}

started() {
  grep -cxF "$1" "$shells" || true
}

wrappers_gone() {
  ! pgrep -f "tmux-workspace run|$t/bin/" >/dev/null
}

# --- Nothing remembered: one desktop workspace in ~ -------------------------

tmux-workspace start
[[ $(saved) == "local:~" ]] || fail "first start saved '$(saved)'"
[[ $(names) == "~" ]] || fail "first start opened '$(names)'"
wait_for '(($(started "local $HOME") == 1))' "a local shell in ~"
pass "first start opens one desktop workspace in ~ and remembers it"

tmux-workspace start
[[ $(names) == "~" ]] || fail "second start changed the session: '$(names)'"
pass "start leaves an existing session alone"

# --- Adding workspaces --------------------------------------------------------

mkdir -p "$HOME/proj-a" "$t/remote/dev/openrep" "$t/remote/homelab/Workspace/nixos"
tmux-workspace add local '~/proj-a'
tmux-workspace add dev '~/openrep'
tmux-workspace add homelab '~/Workspace/nixos'
[[ $(names) == "~ proj-a dev:openrep homelab:nixos" ]] || fail "windows after add: '$(names)'"
[[ $(saved) == "local:~ local:~/proj-a dev:~/openrep homelab:~/Workspace/nixos" ]] ||
  fail "saved after add: '$(saved)'"
[[ $(tmux display-message -p -t =main: '#{window_name}') == homelab:nixos ]] ||
  fail "add did not switch to the new workspace"
wait_for '(($(started "local $HOME/proj-a") == 1))' "a local shell in ~/proj-a"
wait_for '(($(started "dev $t/remote/dev/openrep") == 1))' "a dev shell in ~/openrep"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 1))' "a homelab shell in ~/Workspace/nixos"
pass "add opens local and remote workspaces in their folders, in order, and remembers them"

# --- Restart ------------------------------------------------------------------

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
[[ $(saved) == "local:~ local:~/proj-a dev:~/openrep homelab:~/Workspace/nixos" ]] ||
  fail "kill-server changed the saved list: '$(saved)'"
tmux-workspace start
[[ $(names) == "~ proj-a dev:openrep homelab:nixos" ]] || fail "windows after restart: '$(names)'"
wait_for '(($(started "dev $t/remote/dev/openrep") == 2))' "the dev shell to come back in ~/openrep"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 2))' "the homelab shell to come back"
wait_for '(($(started "local $HOME/proj-a") == 2))' "the local shell to come back in ~/proj-a"
pass "after tmux is killed, start brings back the same workspaces in the same order"

# --- Closing ------------------------------------------------------------------

tmux-workspace close "$(window_id proj-a)"
[[ $(names) == "~ dev:openrep homelab:nixos" ]] || fail "windows after close: '$(names)'"
[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos" ]] || fail "saved after close: '$(saved)'"
pass "close forgets the workspace and closes its window"

tmux send-keys -t "$(window_id dev:openrep)" 0 Enter
wait_for '[[ $(names) == "~ homelab:nixos" ]]' "the dev window to close after exit"
wait_for '[[ $(saved) == "local:~ homelab:~/Workspace/nixos" ]]' "exit to forget the dev workspace"
pass "exit in a workspace's shell forgets it"

# --- Lost connection ------------------------------------------------------------

touch "$t/down-homelab"
tmux send-keys -t "$(window_id homelab:nixos)" 255 Enter
sleep 1
[[ $(names) == "~ homelab:nixos" ]] || fail "a dropped connection closed the window: '$(names)'"
[[ $(saved) == "local:~ homelab:~/Workspace/nixos" ]] || fail "a dropped connection changed the saved list: '$(saved)'"
rm "$t/down-homelab"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 3))' "the homelab shell to reconnect"
pass "a dropped or refused connection keeps the workspace and reconnects to its folder"

# --- Reordering -----------------------------------------------------------------

tmux swap-window -s "$(window_id homelab:nixos)" -t "$(window_id '~')"
tmux-workspace save
[[ $(saved) == "homelab:~/Workspace/nixos local:~" ]] || fail "saved after reorder: '$(saved)'"
tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
tmux-workspace start
[[ $(names) == "homelab:nixos ~" ]] || fail "windows after reorder and restart: '$(names)'"
pass "a new order is remembered across a restart"

# --- Killed windows are not forgotten ---------------------------------------------

tmux kill-window -t "$(window_id '~')"
sleep 1
[[ $(saved) == "homelab:~/Workspace/nixos local:~" ]] || fail "kill-window changed the saved list: '$(saved)'"
pass "a window killed by tmux (as on shutdown) stays remembered"

# --- Missing folders --------------------------------------------------------------

home_shells=$(started "local $HOME")
tmux-workspace add dev '~/missing'
tmux-workspace add local '~/missing'
wait_for '(($(started "dev $t/remote/dev") == 1))' "a dev shell in ~ for a missing folder"
wait_for "((\$(started 'local $HOME') == $((home_shells + 1))))" "a local shell in ~ for a missing folder"
[[ $(saved) == "homelab:~/Workspace/nixos dev:~/missing local:~/missing" ]] ||
  fail "saved with missing folders: '$(saved)'"
pass "a missing folder starts the shell in ~ and keeps the workspace"

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"

# --- Concurrent starts ---------------------------------------------------------------

tmux-workspace start &
tmux-workspace start &
tmux-workspace start
wait
[[ $(tmux list-sessions -F '#{session_name}' | paste -sd ' ') == main ]] || fail "concurrent starts made several sessions"
[[ $(names) == "homelab:nixos dev:missing missing" ]] || fail "windows after concurrent starts: '$(names)'"
pass "kitty windows opening at once share one session"

# --- Project listing -----------------------------------------------------------------

mkdir -p "$HOME/Workspace/nixos/.git" "$HOME/a/b/deep/.git" "$HOME/a/b/c/too-deep/.git" \
  "$HOME/.hidden/repo/.git" "$HOME/web/node_modules/pkg/.git" "$HOME/it's/.git" "$HOME/not-a-repo"
mkdir -p "$HOME/wt" && touch "$HOME/wt/.git"
expected=$(printf '%s\n' '~' '~/Workspace/nixos' '~/a/b/deep' '~/wt')
[[ $(tmux-workspace projects local) == "$expected" ]] ||
  fail "local projects: $(tmux-workspace projects local | paste -sd ' ')"
mkdir -p "$t/remote/dev/openrep/.git" "$t/remote/dev/project/.git"
expected=$(printf '%s\n' '~' '~/openrep' '~/project')
[[ $(tmux-workspace projects dev) == "$expected" ]] ||
  fail "dev projects: $(tmux-workspace projects dev | paste -sd ' ')"
touch "$t/down-dev"
if tmux-workspace projects dev >/dev/null 2>&1; then
  fail "projects succeeded on an unreachable host"
fi
pass "projects lists ~ and git repositories up to three levels deep, skipping hidden, node_modules and quoted folders"

echo "all tmux-workspace tests passed"
