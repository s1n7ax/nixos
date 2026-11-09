#!/usr/bin/env bash
# Runs setup.sh the way a cloud session would, against a throwaway HOME and a
# local repository holding this checkout's skills and agents, then checks
# what a session sees: at setup, after a merge, and with GitHub unreachable.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ai_src=$(cd "$here/.." && pwd)
ai=system/home-manager/applications/dev/ai
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export HOME=$work/home
# Keep the caller's git config (hooks, signing) out of the test.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export AI_SYNC_REPO=file://$work/origin
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
state=$HOME/.local/share/ai-sync
failures=0

check() {
  local what=$1
  shift
  if "$@"; then
    echo "ok   $what"
  else
    echo "FAIL $what"
    failures=$((failures + 1))
  fi
}

not() {
  ! "$@"
}

# Whether text $1 contains $2.
contains() {
  grep -qF -- "$2" <<<"$1"
}

# Runs the SessionStart hook; leaves its stdout in $out and exit code in $rc.
hook() {
  rc=0
  out=$(bash "$state/ai-sync.sh" --hook 2>"$work/hook.err") || rc=$?
}

setup() {
  rc=0
  bash "$here/setup.sh" >"$work/setup.out" 2>&1 || rc=$?
}

origin=$work/origin
mkdir -p "$origin/$(dirname "$ai")"
cp -r "$ai_src" "$origin/$ai"
chmod -R u+w "$origin"
git -C "$origin" init --quiet --initial-branch main
git -C "$origin" add --all
git -C "$origin" commit --quiet --message initial

mapfile -t skills < <(cd "$origin/$ai/skills" && for d in */; do [ -f "$d/SKILL.md" ] && echo "${d%/}"; done)
mapfile -t agents < <(cd "$origin/$ai/agents" && ls -- *.md)

# Things a session already has that ai-sync must leave alone.
mkdir -p "$HOME/.claude/skills/synced/account-skill" "$HOME/.claude/skills/session-start-hook"
echo '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "true"}]}]}, "theme": "dark"}' \
  >"$HOME/.claude/settings.json"

echo "== setup"
setup
check "setup exits 0" test "$rc" = 0

all_skills_linked() {
  local dir name
  for dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    for name in "${skills[@]}"; do
      [ -f "$dir/$name/SKILL.md" ] || return 1
    done
  done
}
check "every skill is in ~/.claude/skills and ~/.agents/skills (${#skills[@]})" all_skills_linked
check "/ship's scripts are reachable at the path the skill names" \
  test -f "$HOME/.agents/skills/ship/scripts/tasks.py"

all_agents_rendered() {
  local name
  for name in "${agents[@]}"; do
    [ -f "$HOME/.claude/agents/$name" ] || return 1
    [ -f "$HOME/.pi/agent/agents/$name" ] || return 1
  done
}
check "every agent is in ~/.claude/agents and ~/.pi/agent/agents (${#agents[@]})" all_agents_rendered

no_pi_tool_names() {
  ! grep -h '^tools: ' "$HOME"/.claude/agents/*.md | grep -qE '\b(read|grep|find|ls|bash|write|edit)\b'
}
check "agents carry Claude Code tool names" no_pi_tool_names
check "code-reviewer is read-only (Read, Grep, Glob, Bash)" \
  grep -qx 'tools: Read, Grep, Glob, Bash' "$HOME/.claude/agents/code-reviewer.md"
check "agents without a tools line keep every tool" \
  not grep -q '^tools:' "$HOME/.claude/agents/worker.md"

check "claude.ai's synced skills and Anthropic's own stay" \
  test -d "$HOME/.claude/skills/synced/account-skill" -a -d "$HOME/.claude/skills/session-start-hook"

hook_count() {
  python3 -c '
import json, sys
s = json.load(open(sys.argv[1]))
print(sum(h["command"] == sys.argv[2] for g in s["hooks"]["SessionStart"] for h in g["hooks"]))
' "$HOME/.claude/settings.json" "bash $state/ai-sync.sh --hook"
}
check "settings.json gets the SessionStart hook" test "$(hook_count)" = 1
check "settings.json keeps what was there" \
  python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert s["theme"] == "dark" and s["hooks"]["Stop"]' \
  "$HOME/.claude/settings.json"
setup
check "setup run twice adds the hook once" test "$(hook_count)" = 1

echo "== a merge on main reaches the next session"
first_skill=${skills[0]}
mkdir -p "$origin/$ai/skills/brand-new"
printf -- '---\nname: brand-new\ndescription: Added on main.\n---\nNew.\n' >"$origin/$ai/skills/brand-new/SKILL.md"
echo "Changed on main." >>"$origin/$ai/skills/ship/SKILL.md"
git -C "$origin" rm --quiet -r "$ai/skills/$first_skill"
sed -i 's/^tools: .*/tools: read, ls/' "$origin/$ai/agents/verifier.md"
printf -- '---\nname: extra\ndescription: Added on main.\ntools: bash\n---\nExtra.\n' >"$origin/$ai/agents/extra.md"
git -C "$origin" add --all
git -C "$origin" commit --quiet --message merge

hook
check "hook exits 0" test "$rc" = 0
check "hook prints nothing when the sync works" test -z "$out"
check "a new skill appears" test -f "$HOME/.claude/skills/brand-new/SKILL.md" -a -f "$HOME/.agents/skills/brand-new/SKILL.md"
check "a changed skill is updated" grep -q 'Changed on main.' "$HOME/.claude/skills/ship/SKILL.md"
check "a removed skill is gone ($first_skill)" \
  test ! -e "$HOME/.claude/skills/$first_skill" -a ! -L "$HOME/.claude/skills/$first_skill" -a ! -L "$HOME/.agents/skills/$first_skill"
check "a changed agent is updated" grep -qx 'tools: Read, Glob' "$HOME/.claude/agents/verifier.md"
check "a new agent appears" grep -qx 'tools: Bash' "$HOME/.claude/agents/extra.md"

git -C "$origin" rm --quiet "$ai/agents/extra.md"
printf -- '---\nname: odd\ndescription: Unknown tool.\ntools: read, teleport\n---\nOdd.\n' >"$origin/$ai/agents/odd.md"
git -C "$origin" add --all
git -C "$origin" commit --quiet --message agents
hook
check "a removed agent is gone" test ! -e "$HOME/.claude/agents/extra.md" -a ! -L "$HOME/.claude/agents/extra.md"
check "an agent with an unknown tool is skipped" test ! -e "$HOME/.claude/agents/odd.md"
check "... and the hook says so" contains "$out" "skipped agent odd"
check "... while the other agents stay" test -f "$HOME/.claude/agents/code-reviewer.md"

python3 -c '
import json, sys
names = json.load(open(sys.argv[1]))
names["teleport"] = "Bash"
json.dump(names, open(sys.argv[1], "w"))
' "$origin/$ai/claude-tool-names.json"
git -C "$origin" commit --quiet --all --message "tool name"
hook
check "a tool name added on main reaches the cloud without a re-paste" \
  grep -qx 'tools: Read, Bash' "$HOME/.claude/agents/odd.md"
git -C "$origin" rm --quiet "$ai/agents/odd.md"
git -C "$origin" commit --quiet --message fix

echo "== main without the skills directory"
git -C "$origin" mv "$ai" "$ai.moved"
git -C "$origin" commit --quiet --message move
hook
check "hook warns" contains "$out" "has no $ai/skills"
check "the last copy's skills stay" test -f "$HOME/.claude/skills/ship/SKILL.md"
git -C "$origin" mv "$ai.moved" "$ai"
git -C "$origin" commit --quiet --message "move back"

echo "== GitHub unreachable"
mv "$origin" "$origin.away"
hook
check "hook still exits 0" test "$rc" = 0
valid_warning() {
  python3 -c '
import json, sys
r = json.loads(sys.argv[1])
assert "could not sync" in r["systemMessage"], r
assert r["hookSpecificOutput"]["hookEventName"] == "SessionStart"
assert "could not sync" in r["hookSpecificOutput"]["additionalContext"]
' "$1"
}
check "hook warns the user and Claude" valid_warning "$out"
check "skills from the last sync still work" test -f "$HOME/.claude/skills/ship/SKILL.md"
check "agents from the last sync still work" test -f "$HOME/.claude/agents/code-reviewer.md"

echo "== a fresh environment while GitHub is unreachable"
rm -rf "$state" "$HOME/.claude/skills" "$HOME/.claude/agents"
setup
check "setup still exits 0" test "$rc" = 0
check "setup still adds the hook" test "$(hook_count)" = 1
hook
check "hook says there are no skills" contains "$out" "has none of its skills"
mv "$origin.away" "$origin"
hook
check "the next session's hook fetches and links them" test -z "$out" -a -f "$HOME/.claude/skills/ship/SKILL.md"

echo "== the installed script passes shellcheck"
if command -v shellcheck >/dev/null; then
  check "shellcheck ai-sync.sh" shellcheck "$state/ai-sync.sh"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
