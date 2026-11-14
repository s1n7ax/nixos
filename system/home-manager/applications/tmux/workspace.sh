# tmux-workspace: one tmux session whose windows are project workspaces, each
# a shell in a folder on this machine ("local") or on an SSH host. The list of
# workspaces, in window order, is kept in a state file and rebuilt the next
# time the session has to be created (after a reboot or a killed tmux).
#
#   tmux-workspace attach              attach to the session, rebuilding it first
#   tmux-workspace start               rebuild the session if it is missing
#   tmux-workspace add <host> <dir>    open a workspace and switch to it
#   tmux-workspace run <host> <dir>    the command every workspace window runs
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
  echo "usage: tmux-workspace attach|start|save|switch|list|pick [<host>...]|add <host> <dir>|run <host> <dir>|close <window-id>|projects <host>" >&2
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

# The window name format of a workspace on $1: window_name's rule applied to
# the folder its shell last reported (pane_path, a URL; see reported), or the
# name it was opened with until the shell reports one. tmux cannot decode the
# URL, so the name may hold %-escapes; its change is what triggers a save,
# which works out the real folder. ':' ends a tmux modifier, so the patterns
# avoid it.
name_format() {
  local prefix='' reported='#{pane_path}' path='#{s|^[^/]*//[^/]*||:pane_path}' home
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
  local host=$1 dir=$2 id
  shift 2
  id=$(PATH=$user_path "$tmux_bin" "$@" -d -P -F '#{window_id}' -n "$(window_name "$host" "$dir")" -c "$HOME" \
    -- "$self" run "$host" "$dir") || return 1
  tmux set-option -w -t "$id" @ws_host "$host" \; set-option -w -t "$id" @ws_dir "$dir" \; \
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
  create_window "$1" "$2" new-window -a -t "=$session:{end}"
}

# Writes the session's workspaces to the state file, leaving out windows
# whose @ws_host was cleared (closing ones). Writes nothing when tmux or the
# session is gone. A workspace is saved in the folder its shell last
# reported, which also becomes its @ws_dir, or else the one it was opened in.
# Fields are space separated because tmux prints a tab as "_" without a UTF-8
# locale; the folder comes last, so spaces inside it survive.
save() {
  local windows id host dir url
  mkdir -p "$state_dir"
  (
    flock 9
    windows=$(tmux list-windows -t "=$session" -F '#{window_id} #{?@ws_host,#{@ws_host},-} #{@ws_dir}' 2>/dev/null) || exit 0
    tmp=$(mktemp "$state.XXXXXX")
    while read -r id host dir; do
      if [[ $host != - ]]; then
        url=$(tmux display-message -p -t "$id" '#{pane_path}' 2>/dev/null) || true
        url=$(reported_dir "$host" "$url")
        if [[ -n $url && $url != "$dir" ]]; then
          dir=$url
          tmux set-option -w -t "$id" @ws_dir "$dir" 2>/dev/null || true
        fi
        printf '%s\t%s\n' "$host" "$dir"
      fi
    done <<<"$windows" >"$tmp"
    mv -f "$tmp" "$state"
  ) 9>"$state.lock"
}

# Rebuilds the session from the state file when it is missing. Of several
# starts racing (kitty windows opening at once), only the one whose
# new-session wins adds the other workspaces.
start() {
  local entries=() entry
  if tmux has-session -t "=$session" 2>/dev/null; then
    return 0
  fi
  if [[ -s $state ]]; then
    mapfile -t entries <"$state"
  fi
  if ((${#entries[@]} == 0)); then
    entries=($'local\t~')
  fi
  entry=${entries[0]}
  create_window "${entry%%$'\t'*}" "${entry#*$'\t'}" new-session -s "$session" >/dev/null 2>&1 || return 0
  for entry in "${entries[@]:1}"; do
    open_window "${entry%%$'\t'*}" "${entry#*$'\t'}" >/dev/null
  done
  save
}

attach() {
  start
  exec tmux attach-session -t "=$session"
}

add() {
  local id
  id=$(open_window "$1" "$2")
  tmux select-window -t "$id"
  save
}

# Clearing @ws_host first keeps the window out of every save from now on,
# including one a rename hook started before the window is gone.
close() {
  tmux set-option -w -u -t "$1" @ws_host
  save
  tmux kill-window -t "$1"
}

# The shell a remote workspace runs in the folder $1 (relative to home, or
# absolute), as one command line for the host's login shell.
# Only single-quoted words, so fish and POSIX shells read it the same. It ends
# with `exit 0` whatever the shell's last status was, so an exit 255 from ssh
# always means a lost connection.
remote_command() {
  printf '%s' "exec sh -c 'case \$1 in /*) ;; *) set -- \"\$HOME/\$1\" ;; esac; cd -- \"\$1\" 2>/dev/null || { echo \"\$1 is gone, starting in ~\"; cd; }; \"\$SHELL\" -l; exit 0' sh '$1'"
}

# Runs the workspace's shell. A local shell runs once; a remote one is
# reconnected while ssh fails to connect or loses the connection (exit 255).
#
# When the shell ends on its own (`exit`), the workspace is forgotten. When
# tmux killed the window or itself, on_hangup ends this script first, and the
# pane lookup in forget_self fails as a second guard, so nothing is written.
# Ctrl-C only cuts the reconnect wait short.
run() {
  local host=$1 dir=$2 rel status shell_pid=
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
        "$host" "$(remote_command "$rel")" || status=$?
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
  tmux set-option -w -u -t "$id" @ws_host
  save
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
add | run)
  (($# == 3)) || usage
  "$1" "$2" "$3"
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
