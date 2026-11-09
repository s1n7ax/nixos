#!/bin/bash
# Setup script for Claude Code cloud sessions (claude.ai/code): gives every
# cloud session the skills and agents in ../skills and ../agents, as they are
# on main of github.com/s1n7ax/nixos.
#
# Install: paste this whole file into claude.ai/code → environment selector →
# the environment's settings icon → Setup script, and save. claude.ai has no
# API for setup scripts, so repeat that whenever this file changes. Changes to
# the skills and agents themselves need nothing: they arrive on their own.
#
# The cloud runs this once per cached environment (up to about 7 days), so
# what it writes can be old. It therefore installs ai-sync.sh and a
# SessionStart hook that runs it, and ai-sync.sh fetches main again at the
# start of every session. ai-sync.sh:
#
# - links each skill into ~/.claude/skills and ~/.agents/skills (skills refer
#   to each other by ~/.agents/skills/... paths);
# - writes each agent into ~/.claude/agents with Claude Code's tool names;
# - links ~/.pi/agent/agents, where /ship looks when an agent is missing.
#
# It only touches what it linked itself, so other skills (claude.ai's synced/
# and Anthropic's own) stay. When GitHub is unreachable, the session starts
# with the copy it already has, and the hook says so. Never exits non-zero: a
# failed setup script stops the session from starting.

home=${HOME:-/root}
state=$home/.local/share/ai-sync
settings=$home/.claude/settings.json
hook="bash $state/ai-sync.sh --hook"

mkdir -p "$state" "$home/.claude"

cat >"$state/ai-sync.sh" <<'AI_SYNC'
#!/bin/bash
# Installed by system/home-manager/applications/dev/ai/cloud/setup.sh in
# github.com/s1n7ax/nixos; see there. --hook prints a SessionStart hook reply.

repo=${AI_SYNC_REPO:-https://github.com/s1n7ax/nixos.git}
branch=${AI_SYNC_BRANCH:-main}
ai=system/home-manager/applications/dev/ai
home=${HOME:-/root}
state=$home/.local/share/ai-sync
clone=$state/nixos
src=$clone/$ai
rendered=$state/claude-agents
warnings=()

warn() {
  warnings+=("$1")
  echo "ai-sync: $1" >&2
}

# Brings the clone to the tip of $branch. Fails, keeping the last copy, when
# that can't be fetched or no longer has the skills where they are expected.
fetch() {
  if [ -d "$clone/.git" ]; then
    timeout 30 git -C "$clone" fetch --quiet --depth 1 origin "$branch" || return
    if ! git -C "$clone" cat-file -e "FETCH_HEAD:$ai/skills" 2>/dev/null; then
      echo "$branch has no $ai/skills" >&2
      return 1
    fi
    git -C "$clone" reset --quiet --hard FETCH_HEAD
  else
    rm -rf "$clone.tmp"
    timeout 60 git clone --quiet --depth 1 --branch "$branch" --sparse "$repo" "$clone.tmp" || return
    git -C "$clone.tmp" sparse-checkout set "$ai/skills" "$ai/agents" || return
    if [ ! -d "$clone.tmp/$ai/skills" ]; then
      echo "$branch has no $ai/skills" >&2
      return 1
    fi
    rm -rf "$clone" && mv "$clone.tmp" "$clone"
  fi
}

# Points $1 at $2, unless $1 is something ai-sync did not make.
place() {
  if [ -e "$1" ] && ! ours "$1"; then
    warn "$1 already exists and is not ai-sync's; left as is"
    return
  fi
  ln -sfn "$2" "$1"
}

# Whether $1 is a link ai-sync made.
ours() {
  case $(readlink "$1") in
  "$state"/*) return 0 ;;
  esac
  return 1
}

# Removes ai-sync's links in $1 that no longer lead anywhere.
prune() {
  local entry
  for entry in "$1"/*; do
    if ours "$entry" && [ ! -e "$entry" ]; then
      rm -f "$entry"
    fi
  done
}

link_skills() {
  local dest=$1 dir
  mkdir -p "$dest"
  for dir in "$src"/skills/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    dir=${dir%/}
    place "$dest/${dir##*/}" "$dir"
  done
  prune "$dest"
}

# Prints agent $1 with Claude Code's tool names, from claude-tool-names.json,
# which claude.nix reads too. An agent with an unknown name fails, to be
# skipped rather than given every tool.
to_claude() {
  python3 -c '
import json, sys

names_file, agent = sys.argv[1:]
try:
    with open(names_file) as f:
        names = json.load(f)
except (OSError, ValueError) as e:
    sys.exit(f"cannot read {names_file}: {e}")
with open(agent) as f:
    lines = f.read().split("\n")
for i, line in enumerate(lines):
    if line.startswith("tools: "):
        tools = []
        for tool in (t.strip() for t in line[len("tools: "):].split(",")):
            if tool not in names:
                sys.exit(f"unknown tool: {tool}")
            if names[tool] not in tools:
                tools.append(names[tool])
        lines[i] = "tools: " + ", ".join(tools)
sys.stdout.write("\n".join(lines))
' "$src/claude-tool-names.json" "$1"
}

link_agents() {
  local dest=$home/.claude/agents file name
  mkdir -p "$dest" "$rendered"
  rm -f "$rendered"/*.md
  for file in "$src"/agents/*.md; do
    [ -f "$file" ] || continue
    name=${file##*/}
    if to_claude "$file" >"$rendered/$name" 2>"$state/agent.err"; then
      place "$dest/$name" "$rendered/$name"
    else
      rm -f "$rendered/$name"
      warn "skipped agent ${name%.md}: $(cat "$state/agent.err")"
    fi
  done
  prune "$dest"
}

link_all() {
  link_skills "$home/.claude/skills"
  link_skills "$home/.agents/skills"
  link_agents
  mkdir -p "$home/.pi/agent"
  place "$home/.pi/agent/agents" "$src/agents"
}

if ! fetch 2>"$state/fetch.err"; then
  failed="could not sync with $branch of $repo ($(tail -n1 "$state/fetch.err"))"
  if [ -d "$src/skills" ]; then
    warn "$failed, so skills and agents are $branch as of $(git -C "$clone" log -1 --format=%cI)"
  else
    warn "$failed, so this session has none of its skills or agents"
  fi
fi
[ -d "$src/skills" ] && link_all

if [ "${1:-}" = --hook ] && [ ${#warnings[@]} -gt 0 ]; then
  python3 -c '
import json, sys
text = "ai-sync: " + " / ".join(sys.argv[1:])
print(json.dumps({
    "systemMessage": text,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": text + " Tell the user if a skill or agent they ask for is missing or outdated.",
    },
}))
' "${warnings[@]}"
fi
exit 0
AI_SYNC

# Adds the hook to settings.json, keeping whatever else is there.
python3 - "$settings" "$hook" <<'PY' || echo "ai-sync: could not add the SessionStart hook to $settings" >&2
import json, os, sys

path, command = sys.argv[1:]
try:
    with open(path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
groups = settings.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any(h.get("command") == command for g in groups for h in g.get("hooks", [])):
    groups.append({"matcher": "startup|resume", "hooks": [{"type": "command", "command": command}]})
with open(path + ".tmp", "w") as f:
    json.dump(settings, f, indent=2)
os.replace(path + ".tmp", path)
PY

bash "$state/ai-sync.sh"
exit 0
