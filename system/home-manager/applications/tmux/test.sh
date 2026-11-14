# Tests tmux-workspace against a real tmux server in a throwaway HOME. A fake
# ssh runs the remote command locally, with $t/remote/<host> as the host's
# home. With -t, like the real one, it outlives a lost terminal: only a signal
# or the remote shell's exit ends it. A fake shell logs where it started (and
# a local one its PATH), then reads lines: "busy" runs a job that must end
# with its workspace, "drop" makes the fake ssh lose the connection, "cd
# <dir>" changes folder and reports it with OSC 7 (locally unencoded like
# kitty's integration, remotely percent-encoded like fish, with the home as
# /home/me), "osc <url>" reports <url>, anything else exits with that code. Run by the flake check `tmux-workspace` (in the
# Nix sandbox).
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
if [[ -z \${WS_WHERE:-} ]]; then
  echo "\$PATH" >"$t/local-path"
fi
while read -r line; do
  case \$line in
  busy) sleep 4242 ;;
  drop) kill -USR1 "\$FAKE_SSH" ;;
  cd\ *)
    cd "\${line#cd }"
    if [[ -n \${WS_WHERE:-} ]]; then
      where=/home/me\${PWD#"\$HOME"}
      where=\${where//%/%25}
      printf '\\033]7;file://fakehost%s\\033\\\\' "\${where// /%20}"
    else
      printf '\\033]7;kitty-shell-cwd://%s%s\\033\\\\' "\$(uname -n)" "\$PWD"
    fi
    ;;
  osc\ *) printf '\\033]7;%s\\033\\\\' "\${line#osc }" ;;
  *) exit "\${line:-0}" ;;
  esac
done
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
export HOME="$t/remote/\$host" WS_WHERE=\$host SHELL="$t/bin/fakeshell" FAKE_SSH=\$\$
cd "\$HOME"
if [[ -z \$tty ]]; then
  exec sh -c "\$*"
fi
in="$t/ssh-in.\$\$"
mkfifo "\$in"
exec 3<>"\$in"
cat <&0 >"\$in" &
copy=\$!
setsid sh -c "\$*" <"\$in" &
remote=\$!
trap 'kill -HUP -- -\$remote; kill \$copy; exit 255' HUP TERM USR1
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
  tmux list-windows -t =main -F '#{window_id} #{window_name}' | awk -v n="$1" '{ id = $1; sub(/^[^ ]* /, "") } $0 == n { print id }'
}

saved() {
  paste -sd ' ' "$state" | tr '\t' ':'
}

started() {
  grep -cxF "$1" "$shells" || true
}

wrappers_gone() {
  ! pgrep -f "tmux-workspace run|$t/bin/|sleep 4242" >/dev/null
}

# --- Nothing remembered: one desktop workspace in ~ -------------------------

tmux-workspace start
[[ $(saved) == "local:~" ]] || fail "first start saved '$(saved)'"
[[ $(names) == "~" ]] || fail "first start opened '$(names)'"
wait_for '(($(started "local $HOME") == 1))' "a local shell in ~"
pass "first start opens one desktop workspace in ~ and remembers it"

[[ $(<"$t/local-path") == "$PATH" ]] || fail "a workspace shell got PATH $(<"$t/local-path")"
pass "workspace shells get the user's PATH, not the script's tools"

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

jobs_running() {
  pgrep -cf "sleep 4242" || true
}

tmux send-keys -t "$(window_id proj-a)" busy Enter
tmux send-keys -t "$(window_id dev:openrep)" busy Enter
wait_for '(($(jobs_running) == 2))' "busy jobs in a local and a remote workspace"
tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
[[ $(saved) == "local:~ local:~/proj-a dev:~/openrep homelab:~/Workspace/nixos" ]] ||
  fail "kill-server changed the saved list: '$(saved)'"
tmux-workspace start
[[ $(names) == "~ proj-a dev:openrep homelab:nixos" ]] || fail "windows after restart: '$(names)'"
wait_for '(($(started "dev $t/remote/dev/openrep") == 2))' "the dev shell to come back in ~/openrep"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 2))' "the homelab shell to come back"
wait_for '(($(started "local $HOME/proj-a") == 2))' "the local shell to come back in ~/proj-a"
pass "killing tmux ends the workspaces' jobs; start brings back the same workspaces in the same order"

# --- Closing ------------------------------------------------------------------

tmux send-keys -t "$(window_id proj-a)" busy Enter
wait_for '(($(jobs_running) == 1))' "a busy job in a local workspace"
tmux-workspace close "$(window_id proj-a)"
[[ $(names) == "~ dev:openrep homelab:nixos" ]] || fail "windows after close: '$(names)'"
[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos" ]] || fail "saved after close: '$(saved)'"
wait_for '(($(jobs_running) == 0))' "the closed workspace's job to end"
pass "close forgets the workspace, closes its window and ends its job"

tmux send-keys -t "$(window_id dev:openrep)" 0 Enter
wait_for '[[ $(names) == "~ homelab:nixos" ]]' "the dev window to close after exit"
wait_for '[[ $(saved) == "local:~ homelab:~/Workspace/nixos" ]]' "exit to forget the dev workspace"
pass "exit in a workspace's shell forgets it"

# --- Lost connection ------------------------------------------------------------

touch "$t/down-homelab"
tmux send-keys -t "$(window_id homelab:nixos)" drop Enter
sleep 1
[[ $(names) == "~ homelab:nixos" ]] || fail "a dropped connection closed the window: '$(names)'"
[[ $(saved) == "local:~ homelab:~/Workspace/nixos" ]] || fail "a dropped connection changed the saved list: '$(saved)'"
rm "$t/down-homelab"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 3))' "the homelab shell to reconnect"
pass "a dropped or refused connection keeps the workspace and reconnects to its folder"

tmux-workspace add dev '~/openrep'
wait_for '(($(started "dev $t/remote/dev/openrep") == 3))' "a new dev shell in ~/openrep"
tmux send-keys -t "$(window_id dev:openrep)" 255 Enter
wait_for '[[ $(names) == "~ homelab:nixos" ]]' "the dev window to close after exit 255"
[[ $(saved) == "local:~ homelab:~/Workspace/nixos" ]] || fail "saved after exit 255: '$(saved)'"
pass "a remote shell exiting with 255 is an exit, not a lost connection"

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

# --- Following the shell's folder ----------------------------------------------------

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
printf 'local\t~\nhomelab\t~/Workspace/nixos\n' >"$state"
: >"$shells"
tmux-workspace start
mkdir -p "$HOME/Workspace/my proj" "$t/elsewhere"
tmux send-keys -t "$(window_id '~')" "cd $HOME/Workspace/my proj" Enter
tmux send-keys -t "$(window_id homelab:nixos)" "cd $t/remote/homelab" Enter
wait_for '[[ $(names) == "my proj homelab:~" ]]' "workspaces renamed after their shells' folders"
wait_for '[[ $(saved) == "local:~/Workspace/my proj homelab:~" ]]' "the new folders to be saved"
pass "a workspace is renamed after its shell's folder and remembers it"

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
tmux-workspace start
[[ $(names) == "my proj homelab:~" ]] || fail "windows after restart: '$(names)'"
wait_for '(($(started "local $HOME/Workspace/my proj") == 1))' "the local shell to come back in its new folder"
wait_for '(($(started "homelab $t/remote/homelab") == 1))' "the homelab shell to come back in ~"
pass "a restart reopens workspaces in their shells' last folders"

tmux send-keys -t "$(window_id 'my proj')" "cd $t/elsewhere" Enter
wait_for '[[ $(names) == "elsewhere homelab:~" ]]' "the workspace renamed after a folder outside home"
wait_for '[[ $(saved) == "local:$t/elsewhere homelab:~" ]]' "a folder outside home to be saved"
tmux send-keys -t "$(window_id homelab:~)" "cd $t/remote/homelab/Workspace/nixos" Enter
wait_for '[[ $(names) == "elsewhere homelab:nixos" ]]' "the homelab workspace renamed again"
wait_for '[[ $(saved) == "local:$t/elsewhere homelab:~/Workspace/nixos" ]]' "the homelab folder to be saved again"
tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
tmux-workspace start
wait_for '(($(started "local $t/elsewhere") == 1))' "the local shell to come back outside home"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 2))' "the homelab shell to come back in ~/Workspace/nixos"
pass "a folder outside home is remembered by its absolute path"

mkdir -p "$HOME/50%dev" "$t/remote/homelab/my 50%" "$t/remote/homelab/-foo"
tmux send-keys -t "$(window_id elsewhere)" "cd $HOME/50%dev" Enter
tmux send-keys -t "$(window_id homelab:nixos)" "cd $t/remote/homelab/my 50%" Enter
wait_for '[[ $(names) == "50%dev homelab:my%2050%25" ]]' "workspaces renamed after folders with % and spaces"
wait_for '[[ $(saved) == "local:~/50%dev homelab:~/my 50%" ]]' "folders with % and spaces to be saved as they are"
[[ $(tmux-workspace list | paste -sd '|') == "1: 50%dev|2: homelab:my 50%" ]] ||
  fail "list after folders with % and spaces: '$(tmux-workspace list | paste -sd '|')'"
pass "switch lists and remembers folders by their real names, whichever way the shell encodes them"

tmux send-keys -t "$(window_id 50%dev)" "osc file://otherhost/srv/data" Enter
sleep 1
tmux display-message -p '' >/dev/null
sleep 1
[[ $(names) == "50%dev homelab:my%2050%25" ]] || fail "a folder on another host renamed a local workspace: '$(names)'"
[[ $(saved) == "local:~/50%dev homelab:~/my 50%" ]] || fail "a folder on another host was saved: '$(saved)'"
pass "a folder reported from another host (a shell in ssh) is ignored by a local workspace"

tmux-workspace add homelab '~/-foo'
wait_for '(($(started "homelab $t/remote/homelab/-foo") == 1))' "a homelab shell in ~/-foo"
pass "a remote folder starting with - opens"

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"

# --- Project listing -----------------------------------------------------------------

mkdir -p "$HOME/Workspace/nixos/.git" "$HOME/a/b/deep/.git" "$HOME/a/b/c/too-deep/.git" \
  "$HOME/.hidden/repo/.git" "$HOME/web/node_modules/pkg/.git" "$HOME/it's/.git" "$HOME/not-a-repo"
mkdir -p "$HOME/wt" "$HOME/locked/repo/.git" && touch "$HOME/wt/.git" && chmod 000 "$HOME/locked"
expected=$(printf '%s\n' '~' '~/Workspace/nixos' '~/a/b/deep' '~/wt')
[[ $(tmux-workspace projects local) == "$expected" ]] ||
  fail "local projects: $(tmux-workspace projects local | paste -sd ' ')"
chmod 755 "$HOME/locked"
mkdir -p "$t/remote/dev/openrep/.git" "$t/remote/dev/project/.git"
expected=$(printf '%s\n' '~' '~/openrep' '~/project')
[[ $(tmux-workspace projects dev) == "$expected" ]] ||
  fail "dev projects: $(tmux-workspace projects dev | paste -sd ' ')"
touch "$t/down-dev"
if tmux-workspace projects dev >/dev/null 2>&1; then
  fail "projects succeeded on an unreachable host"
fi
pass "projects lists ~ and git repositories up to three levels deep, skipping hidden, node_modules, quoted and unreadable folders"

echo "all tmux-workspace tests passed"
