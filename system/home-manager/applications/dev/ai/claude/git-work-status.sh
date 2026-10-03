# Stop hook: warn when work is finished locally but not committed / pushed / PR'd.
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
if [[ -n "$cwd" && -d "$cwd" ]]; then
  cd "$cwd" 2>/dev/null || exit 0
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

notes=()

dirty=$(git --no-optional-locks status --porcelain 2>/dev/null)
if [[ -n "$dirty" ]]; then
  n=$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')
  notes+=("$n uncommitted file(s)")
fi

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
if [[ -n "$branch" ]]; then
  default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  default=${default#origin/}
  if [[ -z "$default" ]]; then
    for c in main master; do
      git show-ref --verify --quiet "refs/remotes/origin/$c" && { default=$c; break; }
    done
  fi

  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)

  if [[ -n "$upstream" ]]; then
    ahead=$(git rev-list --count "$upstream..HEAD" 2>/dev/null)
    [[ ${ahead:-0} -gt 0 ]] && notes+=("${ahead} commit(s) not pushed to ${upstream}")
  elif [[ -n "$default" ]]; then
    ahead=$(git rev-list --count "origin/${default}..HEAD" 2>/dev/null)
    [[ ${ahead:-0} -gt 0 ]] && notes+=("${ahead} commit(s) on '${branch}', which has no remote branch yet")
  fi

  if [[ -n "$upstream" && -n "$default" && "$branch" != "$default" ]] && command -v gh >/dev/null 2>&1; then
    beyond=$(git rev-list --count "origin/${default}..HEAD" 2>/dev/null)
    if [[ ${beyond:-0} -gt 0 ]]; then
      pr=$(timeout 8 gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)
      [[ -z "$pr" ]] && notes+=("branch '${branch}' has ${beyond} commit(s) beyond ${default} but no open PR")
    fi
  fi
fi

[[ ${#notes[@]} -eq 0 ]] && exit 0

joined=$(printf '%s; ' "${notes[@]}")
jq -n --arg m "Unfinished git work in $(basename "$PWD"): ${joined%; }" '{systemMessage: $m}'
