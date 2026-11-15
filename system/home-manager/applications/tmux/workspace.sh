# tmux-workspace: one tmux session whose windows are project workspaces, each
# a shell in a folder on this machine ("local") or on an SSH host. The list of
# workspaces, in window order, is kept in a state file and rebuilt the next
# time the session has to be created (after a reboot or a killed tmux).
#
#   tmux-workspace attach              attach to the session, rebuilding it first
#   tmux-workspace start               rebuild the session if it is missing
#   tmux-workspace add <host> <dir>    open a workspace and switch to it
#   tmux-workspace run <host> <dir> <session>
#                                      the command every workspace window runs
#   tmux-workspace close <window-id>   forget a workspace and close its window
#   tmux-workspace save                write the current workspaces to the state file
#   tmux-workspace projects <host>     list the folders the picker offers on a host
#   tmux-workspace pick [<host>...]    pick a machine, then a project, and open it
#   tmux-workspace switch              pick an open workspace and switch to it
#   tmux-workspace list                list the open workspaces as switch shows them
#
# <dir> is relative to the home directory, written "~" or "~/<path>", so one
# entry works on hosts whose home paths differ. A folder outside home is
# written as its absolute path.
#
# A workspace on an SSH host outlives this machine: its shell runs in a tmux
# session on the host (<session>, "-" for a local workspace), so what runs in
# it keeps running while this machine is off, asleep or disconnected, and the
# workspace attaches to it again when it reconnects or is rebuilt. Closing the
# workspace leaves the session running, and opening the same folder again
# brings it back; only `exit` in its shell ends it. A host without tmux gets
# a plain shell that ends with the connection.
#
# A workspace follows its shell: when the shell reports a new folder (OSC 7,
# as fish does on every prompt), the window is renamed after it, and the
# rename saves the folder, so switch shows it and a restart reopens the
# workspace there. tmux runs the rename hook on its next event (the status
# clock, output or a key), so a save can lag a rename by seconds.
#
# Only that rename hook saves; the unlink hooks never do: tmux unlinks every
# window while it shuts down, and saving then would write an empty list right
# before a reboot.

# $tools (this script's pinned tools, set by package.nix) come first only for
# the script itself. The tmux server and the workspace shells get the user's
# own PATH, so a rebuild's new tools reach them without restarting tmux.
user_path=$PATH
PATH=${tools:?}:$PATH
tmux_bin=$(command -v tmux)

session=${TMUX_WORKSPACE_SESSION:-main}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/tmux-workspace
state=$state_dir/$session
self=$(readlink -f "$0")

usage() {
  echo "usage: tmux-workspace attach|start|save|switch|list|pick [<host>...]|add <host> <dir>|run <host> <dir> <session>|close <window-id>|projects <host>" >&2
  exit 2
}

window_name() {
  local host=$1 dir=$2
  if [[ $host == local ]]; then
    echo "${dir##*/}"
  else
    echo "$host:${dir##*/}"
  fi
}

# The home folder pattern (an extended regex) for host $1: $HOME here, and
# /home/<user>, /Users/<user> or /root on an SSH host, whose home path is not
# known here.
home_pattern() {
  if [[ $1 == local ]]; then
    sed 's/[][\.*^$+?(){}|/%]/\\&/g' <<<"$HOME"
  else
    echo '/home/[^/]+|/Users/[^/]+|/root'
  fi
}

# The tmux format of the folder the shell of a workspace on $1 last reported,
# a URL (see reported_dir): pane_path, set by the shell's OSC 7. The tmux
# session on an SSH host keeps the OSC 7 to itself and sends the URL as its
# terminal title instead (see remote_script), so there pane_title wins when it
# is a file URL; a plain shell's own title (a host without tmux) may hold any
# other URL, of a command it runs. ':' ends a tmux modifier, so the pattern
# avoids it.
url_format() {
  if [[ $1 == local ]]; then
    echo '#{pane_path}'
  else
    echo '#{?#{m:file?//*/*,#{pane_title}},#{pane_title},#{pane_path}}'
  fi
}

# The window name format of a workspace on $1: window_name's rule applied to
# the folder its shell last reported (see url_format), or the name it was
# opened with until the shell reports one. tmux cannot decode the URL, so the
# name may hold %-escapes; its change is what triggers a save, which works out
# the real folder. ':' ends a tmux modifier, so the patterns avoid it.
name_format() {
  local prefix='' reported path home
  reported=$(url_format "$1")
  path="#{s|^[^/]*//[^/]*||:$reported}"
  if [[ $1 == local ]]; then
    reported="#{m:*//$(uname -n)/*,#{pane_path}}"
  else
    prefix="$1:"
  fi
  home="#{s%^($(home_pattern "$1"))\$%~%:$path}"
  printf '%s\n' "#{?$reported,$prefix#{s%^.*/([^/])%\\1%:$home},#{window_name}}"
}

# Runs a tmux command that creates a workspace window (new-session or
# new-window, with its own flags) and prints the window's id.
create_window() {
  local host=$1 dir=$2 remote=$3 id
  shift 3
  id=$(PATH=$user_path "$tmux_bin" "$@" -d -P -F '#{window_id}' -n "$(window_name "$host" "$dir")" -c "$HOME" \
    -- "$self" run "$host" "$dir" "$remote") || return 1
  tmux set-option -w -t "$id" @ws_host "$host" \; set-option -w -t "$id" @ws_dir "$dir" \; \
    set-option -w -t "$id" @ws_session "$remote" \; \
    set-option -w -t "$id" automatic-rename-format "$(name_format "$host")" \; \
    set-option -w -t "$id" automatic-rename on \; \
    set-hook -w -t "$id" window-renamed "run-shell -b '$self save'"
  echo "$id"
}

# The <dir> of the folder the shell of a workspace on $1 last reported, from
# its pane_path URL ($2): file://<host><path>, percent-encoded, as fish sends
# it, or kitty-shell-cwd://<host><path>, not encoded, as kitty's shell
# integration sends it. Prints nothing when the URL is not one, a local
# workspace's URL names another host (a shell in ssh), or the folder is one
# that a state file line (newline) or remote_command (single quote) cannot
# hold.
reported_dir() {
  local rest=${2#*://} path
  [[ $2 == *://* && $rest == */* ]] || return 0
  path=/${rest#*/}
  if [[ $1 == local && ${rest%%/*} != "$(uname -n)" ]]; then
    return 0
  fi
  if [[ $2 == file://* ]]; then
    path=$(printf '%s' "$path" | sed 's/\\/\\\\/g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')
    printf -v path '%b' "$path"
  fi
  [[ $path != *[$'\n\'']* ]] || return 0
  if [[ $path =~ ^($(home_pattern "$1"))(/.*)?$ ]]; then
    echo "~${BASH_REMATCH[-1]}"
  else
    echo "$path"
  fi
}

open_window() {
  create_window "$1" "$2" "$3" new-window -a -t "=$session:{end}"
}

# The name of the first tmux session on an SSH host for a workspace opened in
# the folder $1: the folder itself, with every byte outside [A-Za-z0-9/~-]
# written as _XX (hex). tmux rewrites "." and ":" in a session name, and the
# name is single-quoted in remote_command; this keeps it the same everywhere.
# Further workspaces on the folder get "+2", "+3", ... appended, which the
# encoding never produces.
session_base() {
  local LC_ALL=C dir=$1 name='' char i
  for ((i = 0; i < ${#dir}; i++)); do
    char=${dir:i:1}
    if [[ $char != [A-Za-z0-9/~-] ]]; then
      printf -v char '_%02X' "'$char"
    fi
    name+=$char
  done
  echo "$name"
}

# Where the tmux server holding a host's workspace sessions lives, as sh code
# for the host. Outside /run/user/<uid>, which a host without linger removes
# at logout, taking the socket (and the way back to the sessions) with it.
# shellcheck disable=SC2016
remote_state='${XDG_STATE_HOME:-$HOME/.local/state}/tmux-workspace'

# Lists the workspace sessions running on host $1, in the order they were
# numbered. Fails when the host cannot be reached.
remote_sessions() {
  ssh -o ConnectTimeout=5 "$1" sh -s 2>/dev/null \
    <<<"tmux -S \"$remote_state/tmux.sock\" list-sessions -F \"#{session_name}\" 2>/dev/null; exit 0" |
    sort -t+ -k2,2n
}

# The session a new workspace in the folder $2 on host $1 attaches to: the
# first one of that folder still running on the host with no workspace open
# on it (a closed workspace, which comes back this way), or else a new one.
# When the host cannot be asked, the first one no workspace is open on.
free_session() {
  local host=$1 base open running name n=1
  base=$(session_base "$2")
  open=$(tmux list-windows -t "=$session" -F '#{@ws_host} #{@ws_session}' 2>/dev/null) || true
  running=$(remote_sessions "$host") || true
  while read -r name; do
    if [[ $name == "$base" || $name == "$base"+* ]] && ! grep -qxF "$host $name" <<<"$open"; then
      echo "$name"
      return 0
    fi
  done <<<"$running"
  name=$base
  while grep -qxF "$host $name" <<<"$open" || grep -qxF "$name" <<<"$running"; do
    name=$base+$((++n))
  done
  echo "$name"
}

# Writes the session's workspaces to the state file, leaving out windows
# whose @ws_host was cleared (closing ones), as it first is for the window
# given as $1. Clearing it before saving keeps the window out of every save
# from now on, including one a rename hook started before the window is gone.
# Writes nothing when tmux or the session is gone. A workspace is saved in the
# folder its shell last reported, which also becomes its @ws_dir, or else the
# one it was opened in.
# Fields are space separated because tmux prints a tab as "_" without a UTF-8
# locale; the folder comes last, so spaces inside it survive. A line of the
# state file is "<host> <session> <dir>", tab separated.
save() {
  local windows id host remote dir url reported
  if [[ -n ${1:-} ]]; then
    tmux set-option -w -u -t "$1" @ws_host
  fi
  mkdir -p "$state_dir"
  (
    flock 9
    windows=$(tmux list-windows -t "=$session" \
      -F '#{window_id} #{?@ws_host,#{@ws_host},-} #{?@ws_session,#{@ws_session},-} #{@ws_dir}' 2>/dev/null) || exit 0
    tmp=$(mktemp "$state.XXXXXX")
    while read -r id host remote dir; do
      if [[ $host != - ]]; then
        url=$(tmux display-message -p -t "$id" "$(url_format "$host")" 2>/dev/null) || true
        reported=$(reported_dir "$host" "$url")
        if [[ -n $reported && $reported != "$dir" ]]; then
          dir=$reported
          tmux set-option -w -t "$id" @ws_dir "$dir" 2>/dev/null || true
        fi
        printf '%s\t%s\t%s\n' "$host" "$remote" "$dir"
      fi
    done <<<"$windows" >"$tmp"
    mv -f "$tmp" "$state"
  ) 9>"$state.lock"
}

# Splits a state file line, "<host> <session> <dir>" or, from before
# workspaces had sessions, "<host> <dir>", tab separated, into the caller's
# host, remote ("-" for no session) and dir.
read_entry() {
  host=${1%%$'\t'*} dir=${1#*$'\t'} remote=-
  if [[ $dir == *$'\t'* ]]; then
    remote=${dir%%$'\t'*} dir=${dir#*$'\t'}
  fi
}

# Rebuilds the session from the state file when it is missing. Of several
# starts racing (kitty windows opening at once), only the one whose
# new-session wins adds the other workspaces.
#
# A remote workspace remembered without a session (a state file from before
# workspaces had one) gets the first session of its folder that no other line
# has, without asking the host.
start() {
  local entries=() entry host remote dir n first=1
  local -A taken=()
  if tmux has-session -t "=$session" 2>/dev/null; then
    return 0
  fi
  if [[ -s $state ]]; then
    mapfile -t entries <"$state"
  fi
  if ((${#entries[@]} == 0)); then
    entries=($'local\t-\t~')
  fi
  for entry in "${entries[@]}"; do
    read_entry "$entry"
    taken["$host $remote"]=1
  done
  for entry in "${entries[@]}"; do
    read_entry "$entry"
    if [[ $host != local && $remote == - ]]; then
      remote=$(session_base "$dir") n=1
      while [[ -n ${taken["$host $remote"]:-} ]]; do
        remote=${remote%+*}+$((++n))
      done
      taken["$host $remote"]=1
    fi
    if ((first)); then
      create_window "$host" "$dir" "$remote" new-session -s "$session" >/dev/null 2>&1 || return 0
      first=0
    else
      open_window "$host" "$dir" "$remote" >/dev/null
    fi
  done
  save
}

attach() {
  start
  exec tmux attach-session -t "=$session"
}

add() {
  local id remote=-
  if [[ $1 != local ]]; then
    remote=$(free_session "$1" "$2")
  fi
  id=$(open_window "$1" "$2" "$remote")
  tmux select-window -t "$id"
  save
}

close() {
  save "$1"
  tmux kill-window -t "$1"
}

# What a remote workspace runs on its host, as sh code without a single quote
# (see remote_command): $1 is its folder (relative to home, or absolute) and
# $2 its session.
#
# The shell runs in the tmux session $2, created in the folder when it is not
# running yet, on a tmux server of its own, so the host's other tmux sessions
# and its tmux config stay untouched. That tmux is invisible: no status line
# and no prefix key, so this machine's tmux keeps every key, and it passes
# extended keys and the mouse on to the programs. It keeps tmux's mouse
# bindings and the scrollback: this machine's tmux only sees the session's
# screen, so the wheel scrolls back, and a drag copies, in the session, the
# way they do in a local workspace (emacs keys, as tmux picks here). The copy
# reaches this machine's clipboard through its tmux, which needs
# set-clipboard on for that (see tmux.nix). The config is read when the
# server starts.
#
# The exit status tells run what happened: 0 when the session is gone (the
# shell exited), whatever the shell's last status was, and 255, like a lost
# connection, when it is still running (it was detached by hand), so the
# workspace attaches again. A host without tmux, or where tmux fails, gets a
# plain shell.
remote_script=$(
  cat <<'EOF'
case $1 in /*) ;; *) set -- "$HOME/$1" "$2" ;; esac
cd -- "$1" 2>/dev/null || { echo "$1 is gone, starting in ~"; cd; }
state=REMOTE_STATE
if command -v tmux >/dev/null 2>&1 && mkdir -p "$state"; then
  cat >"$state/tmux.conf" <<"CONF"
set -g status off
set -g prefix None
set -g mouse on
set -g mode-keys emacs
set -s escape-time 0
set -s extended-keys on
set -g default-terminal tmux-256color
set -as terminal-features ",*:RGB"
set -g history-limit 50000
set -g set-titles on
set -g set-titles-string "#{pane_path}"
CONF
  tmux -S "$state/tmux.sock" -f "$state/tmux.conf" new-session -A -s "$2" -- "$SHELL" -l
  status=$?
  if tmux -S "$state/tmux.sock" has-session -t "=$2" 2>/dev/null; then
    exit 255
  fi
  if [ "$status" -ne 0 ]; then
    echo "tmux failed here: what runs in this workspace ends with the connection."
    "$SHELL" -l
  fi
else
  echo "No tmux here: what runs in this workspace ends with the connection."
  "$SHELL" -l
fi
exit 0
EOF
)
remote_script=${remote_script/REMOTE_STATE/$remote_state}

# remote_script for the folder $1 and the session $2, as one command line for
# the host's login shell. Only single-quoted words, so fish and POSIX shells
# read it the same.
remote_command() {
  printf '%s' "exec sh -c '$remote_script' sh '$1' '$2'"
}

# Runs the workspace's shell. A local shell runs once; a remote one is
# reconnected, to its session when the host still has it, while ssh fails to
# connect or loses the connection (exit 255).
#
# When the shell ends on its own (`exit`), the workspace is forgotten. When
# tmux killed the window or itself, on_hangup ends this script first, and the
# pane lookup in forget_self fails as a second guard, so nothing is written.
# Ctrl-C only cuts the reconnect wait short.
run() {
  local host=$1 dir=$2 remote=$3 rel status shell_pid=
  case $dir in
  \~ | \~/*) rel=${dir#\~} rel=${rel#/} ;;
  *) rel=$dir ;;
  esac
  trap on_hangup HUP TERM
  trap : INT
  if [[ $host == local ]]; then
    if [[ $rel != /* ]]; then
      rel=$HOME/$rel
    fi
    if ! cd -- "$rel" 2>/dev/null; then
      echo "$dir is gone, starting in ~"
      cd
    fi
    run_shell "${SHELL:-sh}" -l || true
  else
    while :; do
      status=0
      run_shell ssh -t -o ConnectTimeout=5 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
        "$host" "$(remote_command "$rel" "$remote")" || status=$?
      if ((status != 255)); then
        break
      fi
      echo "Lost $host. Reconnecting in 5s (Enter: now, prefix x: close this workspace)."
      read -rs -t 5 || true
    done
  fi
  forget_self
}

# Runs a command on the terminal with the user's PATH and returns its status.
#
# It runs in the background and is waited for. A lost terminal signals only
# this script (the session leader), and bash runs a trap only once a
# foreground command has ended; a shell busy with a job, or ssh, outlives its
# terminal, so a foreground command would keep both running forever. Once
# on_hangup has exited this script, the kernel hangs up the terminal's
# foreground jobs. <&0 gives the command the terminal back; like every
# background command it starts with Ctrl-C ignored, which fish undoes and ssh
# only notices while connecting.
run_shell() {
  local status=0
  PATH=$user_path "$@" <&0 &
  shell_pid=$!
  wait "$shell_pid" || status=$?
  while kill -0 "$shell_pid" 2>/dev/null; do
    status=0
    wait "$shell_pid" || status=$?
  done
  shell_pid=
  return "$status"
}

on_hangup() {
  if [[ -n ${shell_pid:-} ]]; then
    kill -HUP "$shell_pid" 2>/dev/null || true
  fi
  exit 129
}

forget_self() {
  local id
  id=$(tmux display-message -p -t "${TMUX_PANE:?}" '#{window_id}' 2>/dev/null) || return 0
  save "$id"
}

# Lists "~" and every git repository up to three levels under home, as
# "~/<path>". Folders with a single quote are left out: remote_command could
# not quote them. find's errors (an unreadable folder) are ignored so they do
# not hide the other projects, and -xdev keeps it out of other mounts, such
# as network or FUSE drives that can stall. Fails only when ssh does.
projects() {
  local host=$1 list
  local script='cd && find . -xdev -mindepth 1 -maxdepth 4 -name .git -printf "%h\n" -prune -o \( -name ".*" -o -name node_modules \) -prune 2>/dev/null; exit 0'
  if [[ $host == local ]]; then
    list=$(sh -c "$script") || return 1
  else
    list=$(ssh -o ConnectTimeout=5 "$host" sh -s <<<"$script") || return 1
  fi
  echo "~"
  sed -n "/'/d; s|^\./|~/|p" <<<"$list" | sort
}

pick() {
  local host list dir
  host=$(printf '%s\n' local "$@" | fzf --reverse --prompt='machine> ') || return 0
  if ! list=$(projects "$host"); then
    echo "Could not list the projects on $host. Press a key."
    read -rsn1 || true
    return 0
  fi
  dir=$(fzf --reverse --prompt="$host project> " <<<"$list") || return 0
  add "$host" "$dir"
}

# Lists the session's windows as "<index>: <name>", a workspace named by
# window_name's rule from its @ws_dir, which save keeps decoded.
list() {
  local index host dir
  while read -r index host dir; do
    if [[ $host == - ]]; then
      echo "$index: $dir"
    else
      echo "$index: $(window_name "$host" "$dir")"
    fi
  done < <(tmux list-windows -t "=$session" -F '#{window_index} #{?@ws_host,#{@ws_host} #{@ws_dir},- #{window_name}}')
}

switch() {
  local target
  target=$(list | fzf --reverse --prompt='workspace> ') || return 0
  tmux select-window -t "=$session:${target%%:*}"
}

case ${1:-} in
attach | start | save | switch | list)
  "$1"
  ;;
add)
  (($# == 3)) || usage
  add "$2" "$3"
  ;;
run)
  (($# == 4)) || usage
  run "$2" "$3" "$4"
  ;;
close | projects)
  (($# == 2)) || usage
  "$1" "$2"
  ;;
pick)
  shift
  pick "$@"
  ;;
*)
  usage
  ;;
esac
