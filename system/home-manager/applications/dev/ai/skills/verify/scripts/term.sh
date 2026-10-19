#!/usr/bin/env bash
# Drive a terminal the way a user would, and screenshot it.
#
# Every session lives on a private tmux server (socket "verify"), so the
# user's own tmux sessions are never touched. Needs tmux and freeze
# (charmbracelet/freeze); on a Nix machine without them, the script re-runs
# itself inside `nix shell` with both.
#
# Usage:
#   term.sh start <name> [dir] [KEY=VALUE...]  open a clean bash (prompt "$ ") in dir, with extra env
#   term.sh type  <name> <text>                type text, then press Enter
#   term.sh keys  <name> <key>...              press keys: Enter Up Down Left Right Tab Escape BSpace C-c q ...
#   term.sh wait  <name> [timeout]             wait until the screen stops changing (default 30s)
#   term.sh until <name> <regex> [timeout]     wait until the screen matches an extended regex (default 30s)
#   term.sh read  <name>                       print the screen as plain text
#   term.sh clear <name>                       clear the screen and scrollback (at the shell prompt)
#   term.sh shot  <name> <out.png>             save the screen, colours included, as a PNG
#   term.sh stop  <name>...                    close the sessions
#
# Sessions share one tmux server, so name them uniquely per run (e.g.
# "<goal>-before"). The window is 120x35 unless TERM_SIZE=<cols>x<rows> is
# set at start.

set -euo pipefail

if ! command -v tmux >/dev/null || ! command -v freeze >/dev/null; then
  if [[ -z "${VERIFY_TERM_NIX_SHELL:-}" ]] && command -v nix >/dev/null; then
    export VERIFY_TERM_NIX_SHELL=1
    exec nix shell nixpkgs#tmux nixpkgs#charm-freeze --command bash "$0" "$@"
  fi
  echo "term.sh: needs tmux and freeze (https://github.com/charmbracelet/freeze) on PATH" >&2
  exit 127
fi

tm() { tmux -L verify "$@"; }

usage() {
  sed -n '/^# Usage:/,/^# set at start/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

need() { (($# - 1 >= $1)) || usage; }

screen() { tm capture-pane -p -t "$1"; }

drop_trailing_blank_lines() { sed -e :a -e '/^\(\x1b\[[0-9;]*m\)*[[:space:]]*$/{$d;N;ba' -e '}'; }

settle() {
  local name=$1 timeout=${2:-30} prev="" cur stable=0 waited=0
  while ((waited < timeout * 4)); do
    cur=$(screen "$name")
    if [[ "$cur" == "$prev" ]]; then
      ((++stable >= 4)) && return 0
    else
      stable=0
      prev=$cur
    fi
    sleep 0.25
    ((++waited))
  done
  echo "term.sh: screen of '$name' still changing after ${timeout}s" >&2
  return 1
}

until_match() {
  local name=$1 regex=$2 timeout=${3:-30} waited=0
  while ((waited < timeout * 4)); do
    screen "$name" | grep -Eq -- "$regex" && return 0
    sleep 0.25
    ((++waited))
  done
  echo "term.sh: '$regex' did not appear in '$name' within ${timeout}s" >&2
  screen "$name" >&2
  return 1
}

cmd=${1:-}
[[ -n "$cmd" ]] || usage
shift

case "$cmd" in
start)
  need 1 "$@"
  name=$1
  dir=${2:-$PWD}
  shift $(($# < 2 ? $# : 2))
  size=${TERM_SIZE:-120x35}
  envs=()
  for kv in "$@"; do envs+=(-e "$kv"); done
  tm new-session -d -s "$name" -c "$dir" -x "${size%x*}" -y "${size#*x}" "${envs[@]}" \
    "env PS1='\$ ' PROMPT_COMMAND= bash --norc --noprofile"
  until_match "$name" '^[$]( |$)' 10 >/dev/null
  ;;
type)
  need 2 "$@"
  tm send-keys -t "$1" -l -- "$2"
  tm send-keys -t "$1" Enter
  ;;
keys)
  need 2 "$@"
  name=$1
  shift
  tm send-keys -t "$name" "$@"
  ;;
wait)
  need 1 "$@"
  settle "$1" "${2:-30}"
  ;;
until)
  need 2 "$@"
  until_match "$1" "$2" "${3:-30}"
  ;;
read)
  need 1 "$@"
  screen "$1" | drop_trailing_blank_lines
  ;;
clear)
  need 1 "$@"
  tm send-keys -t "$1" C-l
  sleep 0.2
  tm clear-history -t "$1"
  ;;
shot)
  need 2 "$@"
  mkdir -p "$(dirname "$2")"
  tm capture-pane -e -p -t "$1" | drop_trailing_blank_lines |
    freeze --language ansi --window --padding 20 --output "$2" >/dev/null
  echo "$2"
  ;;
stop)
  need 1 "$@"
  for name in "$@"; do tm kill-session -t "$name" 2>/dev/null || true; done
  ;;
*)
  usage
  ;;
esac
