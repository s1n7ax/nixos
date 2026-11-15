# Tests tmux-workspace against a real tmux server in a throwaway HOME. A fake
# ssh runs the remote command locally, with $t/remote/<host> as the host's
# home, a real tmux as the host's tmux (none on a host with $t/notmux-<host>;
# on "broken" it cannot start, its socket path being a folder), TERM=xterm
# whatever the terminal is, as a host that forces its own TERM on every login,
# an SSH_CLIENT of its own per connection,
# and, with -t, on a terminal of its own, as sshd would. Like the real one, it
# outlives a lost terminal: only a signal or the remote command's exit ends
# it, and `drop <host>` makes it lose the connection. A fake shell logs where
# it started, the terminal variables and the SSH_CLIENT it got (and a local
# one its PATH), then
# reads lines: "busy" runs a job,
# "say <text>" prints said:<text>, "later <text>" does so two seconds later,
# "cd <dir>" changes folder and reports it with OSC 7 (locally unencoded like
# kitty's integration, remotely percent-encoded like fish, with the home as
# /home/me), "osc <url>" reports <url>, "title <text>" sets the terminal
# title, "raw <file>" asks for extended keys as Neovim does and writes the
# bytes it is sent for three seconds to <file>, "plain <file>" does so without
# asking for extended keys, anything else exits with that code.
# Run by the flake check `tmux-workspace` (in the Nix sandbox).
#
# Workspace folders are literal "~/<path>" strings, and wait_for evaluates its
# condition each time it polls, hence the two shellcheck exceptions.
# shellcheck disable=SC2016,SC2088
set -euo pipefail

t=$(mktemp -d)

remote_tmux() {
  local host=$1
  shift
  tmux -S "$t/remote/$host/.local/state/tmux-workspace/tmux.sock" "$@"
}

# Ends the hosts' workspace sessions, as a reboot of the hosts would.
reboot_hosts() {
  local home
  for home in "$t"/remote/*; do
    remote_tmux "${home##*/}" kill-server 2>/dev/null || true
  done
}

trap 'tmux kill-server 2>/dev/null || true; reboot_hosts; rm -rf "$t"' EXIT

export HOME=$t/home XDG_STATE_HOME=$t/state TMUX_TMPDIR=$t/sock
export PATH=$t/bin:$PATH
unset TMUX TMUX_PANE
mkdir -p "$HOME" "$TMUX_TMPDIR" "$t/bin" "$t/remote/dev" "$t/remote/homelab" "$t/remote/bare" \
  "$t/remote/broken/.local/state/tmux-workspace/tmux.sock"
touch "$t/notmux-bare"
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
echo "\${SSH_CLIENT:-}" >>"$t/clients.\${WS_WHERE:-local}"
echo "TERM=\$TERM COLORTERM=\${COLORTERM:-} TERM_PROGRAM=\${TERM_PROGRAM:-} TERM_PROGRAM_VERSION=\${TERM_PROGRAM_VERSION:-} TMUX=\${TMUX:-} TMUX_PANE=\${TMUX_PANE:-}" >"$t/env.\${WS_WHERE:-local}"
if [[ -z \${WS_WHERE:-} ]]; then
  echo "\$PATH" >"$t/local-path"
fi
while read -r line; do
  case \$line in
  busy) sleep 4242 ;;
  say\ *) echo "said:\${line#say }" ;;
  later\ *)
    (sleep 2 && echo "said:\${line#later }") &
    echo "\$line" >>"$shells"
    ;;
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
  title\ *) printf '\\033]2;%s\\033\\\\' "\${line#title }" ;;
  raw\ * | plain\ *)
    [[ \$line == plain* ]] || printf '\\033[>4;2m'
    stty raw -echo
    timeout --foreground 3 cat >"\${line#* }"
    stty sane
    printf '\\033[>4;0m'
    ;;
  *) exit "\${line:-0}" ;;
  esac
done
EOF

tmux_dir=$(dirname "$(command -v tmux)")
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
unset TMUX TMUX_PANE TERM_PROGRAM TERM_PROGRAM_VERSION COLORTERM XDG_STATE_HOME
export HOME="$t/remote/\$host" WS_WHERE=\$host SHELL="$t/bin/fakeshell" TERM=xterm SSH_CLIENT="client \$\$"
if [[ -e "$t/notmux-\$host" ]]; then
  PATH=\$(tr ':' '\\n' <<<"\$PATH" | grep -vxF "$tmux_dir" | paste -sd:)
fi
cd "\$HOME"
if [[ -z \$tty ]]; then
  exec sh -c "\$*"
fi
in="$t/ssh-in.\$\$"
mkfifo "\$in"
exec 3<>"\$in"
stty raw -echo
cat <&0 >"\$in" &
copy=\$!
SHELL=$(command -v sh) script -qec "export SHELL='$t/bin/fakeshell'; \$*" /dev/null <"\$in" &
remote=\$!
finish() {
  kill \$copy
  rm -f "\$in"
  stty sane 2>/dev/null
}
trap 'kill -KILL \$remote; finish; exit 255' HUP TERM USR1
wait \$remote
status=\$?
finish
exit \$status
EOF
chmod +x "$t/bin/fakeshell" "$t/bin/ssh"

cat >"$HOME/.tmux.conf" <<EOF
set -s extended-keys on
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

# The window whose $1 (a tmux format) is $2.
window_where() {
  tmux list-windows -t =main -F "#{window_id} $1" | awk -v v="$2" '{ id = $1; sub(/^[^ ]* /, "") } $0 == v { print id }'
}

window_id() {
  window_where '#{window_name}' "$1"
}

# The window of the workspace on host $1 attached to its session $2.
window_of() {
  window_where '#{@ws_host} #{@ws_session}' "$1 $2"
}

screen() {
  tmux capture-pane -p -t "$1"
}

saved() {
  cut -f1,3 "$state" | paste -sd ' ' | tr '\t' ':'
}

saved_sessions() {
  cut -f1,2 "$state" | paste -sd ' ' | tr '\t' ':'
}

# The workspace sessions running on host $1.
sessions() {
  remote_tmux "$1" list-sessions -F '#{session_name}' 2>/dev/null | paste -sd ' '
}

# How many workspaces are attached to the session $2 on host $1.
attached() {
  remote_tmux "$1" list-clients -t "=$2" 2>/dev/null | grep -c . || true
}

started() {
  grep -cxF "$1" "$shells" || true
}

jobs_running() {
  pgrep -cf "sleep 4242" || true
}

drop() {
  pkill -USR1 -f "$t/bin/ssh -t .* $1 exec"
}

wrappers_gone() {
  ! pgrep -f "tmux-workspace run|$t/bin/ssh|script -qec" >/dev/null
}

# Ends tmux, the hosts' sessions and every job, and empties the shell log.
reset() {
  tmux kill-server 2>/dev/null || true
  wait_for wrappers_gone "workspace shells to end after kill-server"
  reboot_hosts
  wait_for '(($(jobs_running) == 0))' "every job to end with its session"
  : >"$shells"
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
[[ $(saved_sessions) == "local:- local:- dev:~/openrep homelab:~/Workspace/nixos" ]] ||
  fail "saved sessions after add: '$(saved_sessions)'"
[[ $(tmux display-message -p -t =main: '#{window_name}') == homelab:nixos ]] ||
  fail "add did not switch to the new workspace"
wait_for '(($(started "local $HOME/proj-a") == 1))' "a local shell in ~/proj-a"
wait_for '(($(started "dev $t/remote/dev/openrep") == 1))' "a dev shell in ~/openrep"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 1))' "a homelab shell in ~/Workspace/nixos"
[[ $(sessions dev) == "~/openrep" && $(sessions homelab) == "~/Workspace/nixos" ]] ||
  fail "sessions after add: dev '$(sessions dev)', homelab '$(sessions homelab)'"
pass "add opens local and remote workspaces in their folders, in order, and remembers them"

[[ $(<"$t/env.homelab") == "TERM=xterm COLORTERM= TERM_PROGRAM= TERM_PROGRAM_VERSION= TMUX= TMUX_PANE=" ]] ||
  fail "a remote workspace's shell got $(<"$t/env.homelab")"
pass "a remote workspace's shell sees the terminal of its connection, not its session's tmux"

tmux send-keys -t "$(window_id '~')" "raw $t/keys.local" Enter
tmux send-keys -t "$(window_id homelab:nixos)" "raw $t/keys.homelab" Enter
wait_for '[[ -e $t/keys.local && -e $t/keys.homelab ]]' "both shells to read keys"
sleep 0.5
for window in '~' homelab:nixos; do
  tmux send-keys -t "$(window_id "$window")" a Home End KPEnter Up F5 C-1 M-x C-Enter BTab
done
sleep 3
keys_local=$(od -An -c "$t/keys.local")
[[ $keys_local == *'[   1   ~'*'[   4   ~'* ]] || fail "the local workspace was not sent Home and End: $keys_local"
[[ $(od -An -c "$t/keys.homelab") == "$keys_local" ]] ||
  fail "keys reach a remote workspace as$(od -An -c "$t/keys.homelab"), a local one as$keys_local"
pass "keys reach a program in a remote workspace as they do in a local one"

tmux send-keys -t "$(window_id '~')" "plain $t/plain.local" Enter
tmux send-keys -t "$(window_id homelab:nixos)" "plain $t/plain.homelab" Enter
wait_for '[[ -e $t/plain.local && -e $t/plain.homelab ]]' "both shells to read plain keys"
sleep 0.5
for window in '~' homelab:nixos; do
  tmux send-keys -t "$(window_id "$window")" a M-BTab b M-x Home
done
sleep 3
plain_local=$(od -An -c "$t/plain.local")
[[ $plain_local == *'a 033   [   Z   b'* ]] || fail "the local workspace was not sent Shift+Tab for Alt+Shift+Tab: $plain_local"
[[ $(od -An -c "$t/plain.homelab") == "$plain_local" ]] ||
  fail "plain keys reach a remote workspace as$(od -An -c "$t/plain.homelab"), a local one as$plain_local"
pass "Alt+Shift+Tab reaches a program that did not ask for extended keys in a remote workspace"

# --- Restart ------------------------------------------------------------------

tmux send-keys -t "$(window_id proj-a)" busy Enter
tmux send-keys -t "$(window_id dev:openrep)" busy Enter
tmux send-keys -t "$(window_id homelab:nixos)" "later while-away" Enter
wait_for '(($(jobs_running) == 2))' "busy jobs in a local and a remote workspace"
wait_for '(($(started "later while-away") == 1))' "the homelab shell to schedule its output"
tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
wait_for '(($(jobs_running) == 1))' "the local job to end"
[[ $(saved) == "local:~ local:~/proj-a dev:~/openrep homelab:~/Workspace/nixos" ]] ||
  fail "kill-server changed the saved list: '$(saved)'"
sleep 2.5
[[ $(jobs_running) == 1 ]] || fail "the remote job ended with tmux"
pass "killing tmux ends a local workspace's job and leaves a remote one's running"

tmux-workspace start
[[ $(names) == "~ proj-a dev:openrep homelab:nixos" ]] || fail "windows after restart: '$(names)'"
wait_for '(($(started "local $HOME/proj-a") == 2))' "the local shell to come back in ~/proj-a"
wait_for '(($(attached dev "~/openrep") == 1))' "the dev workspace to attach to its session"
wait_for 'screen "$(window_id homelab:nixos)" | grep -q "said:while-away"' "the homelab workspace to show what was printed meanwhile"
[[ $(started "dev $t/remote/dev/openrep") == 1 && $(started "homelab $t/remote/homelab/Workspace/nixos") == 1 ]] ||
  fail "a restart started new remote shells"
[[ $(jobs_running) == 1 ]] || fail "the remote job did not survive the restart"
pass "start brings back the same workspaces in the same order, the remote ones still running"

# --- Closing ------------------------------------------------------------------

tmux send-keys -t "$(window_id proj-a)" busy Enter
wait_for '(($(jobs_running) == 2))' "a busy job in a local workspace"
tmux-workspace close "$(window_id proj-a)"
[[ $(names) == "~ dev:openrep homelab:nixos" ]] || fail "windows after close: '$(names)'"
[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos" ]] || fail "saved after close: '$(saved)'"
wait_for '(($(jobs_running) == 1))' "the closed workspace's job to end"
pass "close forgets a local workspace, closes its window and ends its job"

tmux-workspace close "$(window_id dev:openrep)"
[[ $(names) == "~ homelab:nixos" ]] || fail "windows after closing dev: '$(names)'"
[[ $(saved) == "local:~ homelab:~/Workspace/nixos" ]] || fail "saved after closing dev: '$(saved)'"
wait_for '(($(attached dev "~/openrep") == 0))' "the closed workspace to detach"
[[ $(jobs_running) == 1 && $(sessions dev) == "~/openrep" ]] || fail "closing a remote workspace ended what ran in it"
pass "close forgets a remote workspace and leaves what runs in it running"

tmux-workspace add dev '~/openrep'
wait_for '(($(attached dev "~/openrep") == 1))' "the reopened workspace to attach to the running session"
[[ $(started "dev $t/remote/dev/openrep") == 1 && $(sessions dev) == "~/openrep" ]] ||
  fail "reopening a closed folder started a new shell: sessions '$(sessions dev)'"
[[ $(jobs_running) == 1 ]] || fail "the job of the reopened workspace is gone"
pass "opening a closed workspace's folder again brings back what runs in it"

tmux-workspace add dev '~/openrep'
wait_for '(($(started "dev $t/remote/dev/openrep") == 2))' "a second dev shell in ~/openrep"
[[ $(sessions dev) == "~/openrep ~/openrep+2" ]] || fail "sessions with two workspaces on a folder: '$(sessions dev)'"
[[ $(saved_sessions) == "local:- homelab:~/Workspace/nixos dev:~/openrep dev:~/openrep+2" ]] ||
  fail "saved sessions with two workspaces on a folder: '$(saved_sessions)'"
pass "a second workspace on an open folder gets a session of its own"

[[ $(sort -u "$t/clients.dev" | grep -c '^client ') == 2 ]] ||
  fail "the dev shells' connections: $(paste -sd '|' "$t/clients.dev")"
pass "each session's shell sees its own connection, not the one that started the host's tmux"

tmux send-keys -t "$(window_of dev '~/openrep+2')" 0 Enter
wait_for '[[ $(names) == "~ homelab:nixos dev:openrep" ]]' "the dev window to close after exit"
wait_for '[[ $(saved) == "local:~ homelab:~/Workspace/nixos dev:~/openrep" ]]' "exit to forget the dev workspace"
wait_for '[[ $(sessions dev) == "~/openrep" ]]' "the session to end with its shell"
pass "exit in a remote workspace's shell ends its session and forgets it"

tmux-workspace add homelab '~/Workspace/nixos'
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 2))' "a second homelab shell"
tmux-workspace close "$(window_of homelab '~/Workspace/nixos+2')"
wait_for '(($(attached homelab "~/Workspace/nixos+2") == 0))' "the second homelab workspace to detach"
tmux send-keys -t "$(window_of homelab '~/Workspace/nixos')" 0 Enter
wait_for '[[ $(sessions homelab) == "~/Workspace/nixos+2" ]]' "the first homelab session to end"
wait_for '[[ $(names) == "~ dev:openrep" ]]' "the first homelab window to close"
tmux-workspace add homelab '~/Workspace/nixos'
wait_for '(($(attached homelab "~/Workspace/nixos+2") == 1))' "the closed workspace to come back"
[[ $(started "homelab $t/remote/homelab/Workspace/nixos") == 2 && $(sessions homelab) == "~/Workspace/nixos+2" ]] ||
  fail "a new session was made while a closed one was running: '$(sessions homelab)'"
pass "a closed workspace comes back before a new session is made for its folder"

# --- Lost connection ------------------------------------------------------------

touch "$t/down-homelab"
drop homelab
wait_for '(($(attached homelab "~/Workspace/nixos+2") == 0))' "the homelab connection to drop"
sleep 1
[[ $(names) == "~ dev:openrep homelab:nixos" ]] || fail "a dropped connection closed the window: '$(names)'"
[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos" ]] ||
  fail "a dropped connection changed the saved list: '$(saved)'"
rm "$t/down-homelab"
wait_for '(($(attached homelab "~/Workspace/nixos+2") == 1))' "the homelab workspace to reconnect"
tmux send-keys -t "$(window_id homelab:nixos)" "say back" Enter
wait_for 'screen "$(window_id homelab:nixos)" | grep -q "said:back"' "the reconnected shell to answer"
[[ $(started "homelab $t/remote/homelab/Workspace/nixos") == 2 ]] || fail "reconnecting started a new shell"
pass "a dropped or refused connection keeps the workspace and reconnects to its running shell"

remote_tmux homelab detach-client -s '=~/Workspace/nixos+2'
wait_for '(($(attached homelab "~/Workspace/nixos+2") == 0))' "the homelab workspace to be detached"
wait_for '(($(attached homelab "~/Workspace/nixos+2") == 1))' "the detached workspace to attach again"
[[ $(names) == "~ dev:openrep homelab:nixos" && $(started "homelab $t/remote/homelab/Workspace/nixos") == 2 ]] ||
  fail "a detached workspace was closed or restarted: '$(names)'"
pass "a workspace detached from its running session attaches to it again"

remote_tmux homelab list-keys -T root | grep -q WheelUpPane || fail "the session has no wheel binding to scroll back with"
[[ $(remote_tmux homelab show-options -gv status) == off && $(remote_tmux homelab show-options -gv prefix) == None ]] ||
  fail "the session's tmux shows a status line or takes a prefix key"
pass "a session's tmux stays out of sight and keeps the wheel for its scrollback"

mkdir -p "$t/remote/dev/other"
touch "$t/down-dev"
tmux-workspace add dev '~/other'
[[ $(saved_sessions) == "local:- dev:~/openrep homelab:~/Workspace/nixos+2 dev:~/other" ]] ||
  fail "saved sessions after adding on an unreachable host: '$(saved_sessions)'"
rm "$t/down-dev"
wait_for '(($(started "dev $t/remote/dev/other") == 1))' "a dev shell in ~/other once the host is back"
tmux send-keys -t "$(window_id dev:other)" 0 Enter
wait_for '[[ $(names) == "~ dev:openrep homelab:nixos" ]]' "the dev window to close after exit"
pass "a workspace added while its host is unreachable connects once the host is back"

# --- A host without tmux --------------------------------------------------------

mkdir -p "$t/remote/bare/sub"
tmux-workspace add bare '~'
wait_for '(($(started "bare $t/remote/bare") == 1))' "a shell on the host without tmux"
wait_for 'screen "$(window_id bare:~)" | grep -q "No tmux here"' "the note that nothing is kept running"
tmux send-keys -t "$(window_id bare:~)" "cd $t/remote/bare/sub" Enter
wait_for '[[ $(names) == "~ dev:openrep homelab:nixos bare:sub" ]]' "the workspace renamed after its shell's folder"
wait_for '[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos bare:~/sub" ]]' "its folder to be saved"
tmux send-keys -t "$(window_id bare:sub)" busy Enter
wait_for '(($(jobs_running) == 2))' "a busy job on the host without tmux"
drop bare
wait_for '(($(started "bare $t/remote/bare") == 2))' "a new shell after the connection dropped"
[[ $(jobs_running) == 1 ]] || fail "a job outlived its connection on a host without tmux"
pass "a host without tmux gets a plain shell that ends with the connection"

tmux send-keys -t "$(window_id bare:sub)" "title git clone https://example.com/some/repo" Enter
sleep 1
tmux display-message -p '' >/dev/null
sleep 1
[[ $(names) == "~ dev:openrep homelab:nixos bare:sub" ]] || fail "a URL in a shell's title renamed the workspace: '$(names)'"
[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos bare:~/sub" ]] ||
  fail "a URL in a shell's title was saved as the folder: '$(saved)'"
pass "a URL in a plain shell's title is not taken for its folder"

tmux send-keys -t "$(window_id bare:sub)" 255 Enter
wait_for '[[ $(names) == "~ dev:openrep homelab:nixos" ]]' "the window to close after exit 255"
[[ $(saved) == "local:~ dev:~/openrep homelab:~/Workspace/nixos" ]] || fail "saved after exit 255: '$(saved)'"
pass "a remote shell exiting with 255 is an exit, not a lost connection"

tmux-workspace add broken '~'
wait_for '(($(started "broken $t/remote/broken") == 1))' "a shell on the host whose tmux cannot start"
wait_for 'screen "$(window_id broken:~)" | grep -q "tmux failed here"' "the note that tmux failed"
tmux send-keys -t "$(window_id broken:~)" 255 Enter
wait_for '[[ $(names) == "~ dev:openrep homelab:nixos" ]]' "the window to close after exit 255"
pass "a host whose tmux cannot start gets a plain shell"

# --- Reordering -----------------------------------------------------------------

reset
printf 'local\t-\t~\nhomelab\t~/Workspace/nixos\t~/Workspace/nixos\n' >"$state"
tmux-workspace start
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
wait_for 'screen "$(window_id dev:missing)" | grep -q "missing is gone, starting in ~"' "the note that the folder is gone"
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

# --- A state file from before workspaces had sessions -------------------------------

reset
printf 'local\t~\nhomelab\t~/Workspace/nixos\ndev\t~/openrep\nhomelab\t~/Workspace/nixos\ndev\t~/openrep\t~/openrep\n' >"$state"
tmux-workspace start
[[ $(saved_sessions) == "local:- homelab:~/Workspace/nixos dev:~/openrep+2 homelab:~/Workspace/nixos+2 dev:~/openrep" ]] ||
  fail "sessions given to remembered workspaces: '$(saved_sessions)'"
wait_for '(($(started "homelab $t/remote/homelab/Workspace/nixos") == 2))' "a shell for each homelab workspace"
[[ $(sessions homelab) == "~/Workspace/nixos ~/Workspace/nixos+2" ]] || fail "homelab sessions: '$(sessions homelab)'"
pass "workspaces remembered without a session each get their own"

# --- Following the shell's folder ----------------------------------------------------

reset
printf 'local\t~\nhomelab\t~/Workspace/nixos\n' >"$state"
tmux-workspace start
mkdir -p "$HOME/Workspace/my proj" "$t/elsewhere"
tmux send-keys -t "$(window_id '~')" "cd $HOME/Workspace/my proj" Enter
tmux send-keys -t "$(window_id homelab:nixos)" "cd $t/remote/homelab" Enter
wait_for '[[ $(names) == "my proj homelab:~" ]]' "workspaces renamed after their shells' folders"
wait_for '[[ $(saved) == "local:~/Workspace/my proj homelab:~" ]]' "the new folders to be saved"
[[ $(saved_sessions) == "local:- homelab:~/Workspace/nixos" ]] || fail "a new folder changed the session: '$(saved_sessions)'"
pass "a workspace is renamed after its shell's folder and remembers it"

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
tmux-workspace start
[[ $(names) == "my proj homelab:~" ]] || fail "windows after restart: '$(names)'"
wait_for '(($(started "local $HOME/Workspace/my proj") == 1))' "the local shell to come back in its new folder"
wait_for '(($(attached homelab "~/Workspace/nixos") == 1))' "the homelab workspace to attach to its session"
[[ $(started "homelab $t/remote/homelab") == 0 ]] || fail "a restart started a new homelab shell"
pass "a restart reopens a local workspace in its shell's last folder and a remote one in its session"

tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
reboot_hosts
tmux-workspace start
wait_for '(($(started "homelab $t/remote/homelab") == 1))' "the homelab shell to come back in ~"
[[ $(sessions homelab) == "~/Workspace/nixos" ]] || fail "sessions after a host reboot: '$(sessions homelab)'"
pass "a remote workspace whose session is gone starts a new one in its shell's last folder"

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
wait_for '[[ $(names) == "elsewhere homelab:nixos" ]]' "the homelab workspace named after its session's folder"
pass "a folder outside home is remembered by its absolute path"

mkdir -p "$HOME/50%dev" "$t/remote/homelab/my 50%" "$t/remote/homelab/-foo" "$t/remote/homelab/v1.2 beta"
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

tmux-workspace add homelab '~/v1.2 beta'
wait_for '(($(started "homelab $t/remote/homelab/v1.2 beta") == 1))' "a homelab shell in ~/v1.2 beta"
[[ $(sessions homelab) == "~/-foo ~/Workspace/nixos ~/v1_2E2_20beta" ]] || fail "homelab sessions: '$(sessions homelab)'"
tmux kill-server
wait_for wrappers_gone "workspace shells to end after kill-server"
tmux-workspace start
wait_for '(($(attached homelab "~/v1_2E2_20beta") == 1))' "the workspace to attach to its session again"
[[ $(started "homelab $t/remote/homelab/v1.2 beta") == 1 ]] || fail "a restart started a new shell in ~/v1.2 beta"
pass "a folder with characters tmux cannot have in a session name keeps its session"

reset

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
