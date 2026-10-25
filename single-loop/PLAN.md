# Single loop plan

Audit date: 2026-10-25
Repo and commit (or "not a git repo"): s1n7ax/nixos, `bb4e22b` (branch `single-agent-loop`)

Scope: the `/ship` pipeline in `system/home-manager/applications/dev/ai/` (skills and
agents shared by Claude Code and pi). `/ship` is the router; its stages are skills run as
subagents. `/implement` run on its own also dispatches `code-review` and `simplify`
subagents, so changes to those two rows apply there too.

## Status

- [x] Verdicts agreed with the person (end of step 0), 2026-10-25
- [ ] Main eval agreed and baseline measured (end of step 1)

A new session picks up at the first unticked box here, then at the first unticked item in
the worklist.

## Verdicts

Paths are relative to `system/home-manager/applications/dev/ai/`. There are no trace
exports, so traffic and chains are read from the code and marked inferred.

| Agent | Verdict | Why, in one sentence | Evidence | Confidence |
| --- | --- | --- | --- | --- |
| ship | main | Conducts every stage and is the only session that talks to the user, so it becomes the single loop. | skills/ship/SKILL.md:9, 17 | high |
| build | merge:fix | Chains on its own output with fix, and the handoff already lost enough to need a question relay and a gate that distrusts its validation claims. | skills/ship/SKILL.md:99-123, 160; skills/implement/SKILL.md:97-99; commits e788fe8, d37a577 | medium: it does read far more than ship needs afterwards (the kit's reason 1 to keep a context), but ship needs that context to ask its questions and to fix what review finds |
| fix | merge:build | Same procedure and same data as build; `/implement` alone already runs it in the building session, and `/ship` sends it to a cold worker every round. | skills/implement/SKILL.md:183-188; skills/ship/SKILL.md:101, 104, 129, 135, 143 | high |
| code-review | as-tool | An independent check in a fresh context that already returns a structured result from one brief. | skills/implement/SKILL.md:157; agents/code-reviewer.md:13; skills/code-review/SKILL.md:90 | high |
| simplify | merge:code-review | Reads the same diff, requirement and decisions as code-review and repeats its reuse, simplification and efficiency angles; independence comes from a read-only reviewer without a second writing subagent. | skills/simplify/SKILL.md:39-70 vs skills/code-review/SKILL.md:53-64; skills/implement/SKILL.md:192 | medium |
| impl-check | merge:code-review | Same inputs as code-review, and an angle simplify already covers; independence is its only reason for a context, and code-review already gives that. | skills/ship/SKILL.md:125-129 vs skills/simplify/SKILL.md:39-44 | medium |
| final-validation | fold | Fixed steps: the mechanical half is the gate ship already runs, and the acceptance half is what verify tests as the end user. | skills/ship/SKILL.md:116-123, 131-135; skills/verify/SKILL.md:48 | medium |
| verify | as-tool | Reads far more than ship needs afterwards (screenshots and browser snapshots, before and after) and checks independently, from one brief. | skills/ship/SKILL.md:137-143 | high |

Expected end state: `requirement → build, questions, fixes (ship) → review (one read-only
subagent) → gate (ship) → verify (one subagent) → PR`, down from seven subagent roles to two.

Glue that goes away as subagents fold (routers, classifiers, planners, context passing):

- The build, fix and simplify briefs and dispatch rules (skills/ship/SKILL.md:56-74, 95-104).
- The question relay and resume protocol (skills/ship/SKILL.md:106-114) and its other half
  in `/implement` (skills/implement/SKILL.md:97-99).
- The gate's "a worker's claim is not proof" check (skills/ship/SKILL.md:116-123, 160): once
  ship builds, it runs Validate itself. Keeping command output in `gate.log` and reading
  only exit codes stays.
- Every "dispatch a fix `worker` with the report" (skills/ship/SKILL.md:104, 129, 135, 143).
- The impl-check and final-validation report format (skills/ship/SKILL.md:70-93), once both rows are gone.

## Prompt notes

What the fold step will need from each prompt: hard limits that belong in tools, persona
to drop, instructions about other agents, router rules that conflict.

- **Hard limits that live only in prompts.** "Never modify files" (agents/code-reviewer.md,
  agents/verifier.md, agents/acceptance-tester.md). pi enforces it for code-reviewer and
  verifier through their `tools:` lists. Claude Code runs all three as general-purpose
  agents with the rules restated in the brief (skills/ship/SKILL.md:56), and there is no
  `~/.claude/agents/`, so nothing enforces it; on the dev-vm every permission prompt is
  bypassed (claude.nix, `yoloSettings`). These belong in Claude Code agent definitions with
  tool lists, or a hook.
- **Write gates stated as rules.** "No PR before the final validation and `/verify` pass"
  (skills/ship/SKILL.md:18) and "Never commit to the user's current branch"
  (skills/implement/SKILL.md:137) could be enforced by hooks on `gh pr create` and `git commit`.
- **Instructions about other agents**, which go away or change as subagents fold:
  skills/implement/SKILL.md:97-99, skills/verify/SKILL.md:82, skills/simplify/SKILL.md:27,
  skills/ship/SKILL.md:106-114, 141.
- **Conflict between the shared rules and the router.** AGENTS.md:47-49 ("If I didn't ask a
  question STFU", "ELI5 TL;DR") against the long final report `/ship` and `/implement` ask
  for (skills/ship/SKILL.md:153).
- **Duplicate tools.** Claude Code gets three MCP servers twice: playwright and context7 from
  the official plugins (claude.nix:116-117) and from home-manager (mcp.nix:68-77), and
  nixos from home-manager and from a hand-added entry in `~/.claude.json` (outside this
  repo). The plugin's playwright lacks the wrapper without which "Chromium never starts"
  (mcp.nix:22), so a verify run that picks it can fail for reasons unrelated to the change.
- **Name clashes.** This repo's `code-review` and `simplify` skills share names with Claude
  Code's built-in ones, and the code-simplifier plugin (claude.nix:119) adds a third
  simplifier. `/ship` reads its stage skills by path, so it is not affected; a typed
  `/code-review` may be.
- **Persona:** none to drop.

## Evals

Filled in during step 1.

| Eval | What it measures | What to do with it |
| --- | --- | --- |
| none found, built in this step | | |

The 4 goals under `.goals/` are real requests, but 3 of them touch production systems
(a public GitHub repo and release, Home Assistant and a phone, a host rebuild) and 1 has no
requirement file, so they are not usable as tasks as they stand.

Where the eval runs: the dev-vm (`profile/dev-vm/`, `system/nixos/utils/microvm.nix`),
reached as `ssh -p 2222 localhost`. Claude Code 2.1.303 there is logged in, with every
permission prompt bypassed (`yolo`). Found on 2026-10-25, before any run:

- `gh` there is logged in as the real `s1n7ax` account, so an unisolated `/ship` run would
  push branches, open real PRs and post `/verify` comments. Every task runs in a throwaway
  repo whose `origin` is a local bare repo, with `gh` replaced on `PATH` by a stub that
  records calls, and with the real `gh` config hidden.
- `/home` is 97% full (1.7 GB free of 49 GB); `~/.cache/pp-store` holds 27 GB.
- The Nix store overlay (`/nix/.rw-store`, 20 GB) is 100% full, and came up read-only at
  the last boot, so every `nix` command in the VM fails (nixos#243 hit the same error).

Fixed the same day: `~/.cache/pp-store` deleted (the person's call); the store image grown
to 40 GB by the person on the host (nixos#251 sizes new images to match), then
`nix store gc` in the VM: 30 GB free on the store, 29 GB on `/home`. An old commit
(`db5d543`) evaluates in 31 s, private `nix-secrets` input included.

Tasks: `single-loop/eval/tasks.md`, 10 replays of merged PRs, agreed by the person on
2026-10-25. Real requests: each is a merged PR, replayed from its parent commit. Noise
floor at 10 tasks × 3 reps: about ±18 points on the pass rate.

**Blocked: no paid runs (the person's decision, 2026-10-25).** One measured `/ship` run
from 2026-10-22 (own-singlish-keymap, main session plus 6 subagents) used 68 M cache-read,
1.2 M cache-write and 130 k output tokens, about $35 at Opus 5.5 API prices, with stages
2-5 taking about 80 minutes. That puts one variant (10 tasks × 3 reps) at about
$300-1,000, and the 7-variant plan at about $2-7k. Asked to choose a scope, the person
said not to run anything that costs. The verdicts and worklist stay a reading of the
code; no item has a score.

Main metric:

Gaps noticed:

Chains with no task (from `chain_coverage.py`):

Break map: which tasks would notice each kind of break. "none" is a gap to raise.

| What could break | Tasks that would notice | Gap, and the task to add |
| --- | --- | --- |
| Dropped handoff |  |  |
| Lost rule |  |  |
| Shortcut |  |  |
| Wrong pick |  |  |
| Unwanted write |  |  |
| Lost thread |  |  |
| Unhappy path |  |  |

Baseline (variant `baseline`): tasks complete, latency per task, tokens per task, model
calls per task, and how far the score moved between reps.

## Worklist

Merges first, then folds, then as-tool changes. Highest traffic first inside each group.
One line per change. Each variant is compared with the last one that was kept. A reverted
variant keeps its number and is skipped. Variants are numbered in the order the changes
are made, so leave the variant blank until a change starts. If the person takes the list
out of order, say so here.

No traffic data, so the order inside each group is by evidence and risk. Item 1 folds
build and fix straight into ship in one change (step 3), as the kit allows for a thin pair
whose merged agent would be folded next; both are the `worker` prompt plus `/implement`
steps. It is also the change that turns ship from a router into the agent that builds.

- [x] 1. `fold build+fix into ship` · variant: none · compared with: none · result: made unmeasured, the person's call (2026-10-25); judged on real `/ship` runs
- [ ] 2. `merge simplify into code-review` · variant: · compared with: · result:
- [ ] 3. `merge impl-check into code-review` (needs `--critical` tasks) · variant: · compared with: · result:
- [ ] 4. `fold final-validation into ship's gate` · variant: · compared with: · result:
- [ ] 5. `code-review as a tool` (read-only tool list in the harness) · variant: · compared with: · result:
- [ ] 6. `verify as a tool` (write gate on its report directory; resume with answers) · variant: · compared with: · result:

## Changes

One section per change, filled in as it is made. Copy this block.

### Item <n>: `<change>` (variant `<vN>`, branch or commit)

Comparison with `<last kept variant>`: the table from `compare.py`, and tokens used next
to the estimate.

- Tasks that changed score, each with its cause from the trace:
- Tasks that changed route but not score, and what the new route costs:
- What was edited in the main agent's prompt and tool list:
- Checked with no model (unit tests, direct tool calls):
- Reruns, if any: variant names, the commit each side ran on, and each task over all reps:
- Skipped or not measured:
- Decision (who, when): keep / fix / revert
- Left open after the decision:

### Item 1: `fold build+fix into ship` (no variant, branch `single-agent-loop`)

Made without an eval: the person chose not to spend on eval runs. Not measured.

- `/ship` stage 2 now follows `/implement` steps 1-9 in the main session; review and
  simplify stay subagents. Gone: the build/fix worker briefs, the question relay and
  resume, `/implement`'s "When `/ship` runs this step in a subagent", and every "dispatch
  a fix `worker`". The gate is now `/implement`'s Validate run by `/ship` itself, still
  with command output in `gate.log` and only exit codes read.
- Shipped with it, also unmeasured: Claude Code agent definitions generated from
  `agents/*.md` (code-reviewer and verifier get tool lists without Edit or Write
  outside the report; Bash stays, so read-only is still partly a prompt rule), and the
  duplicate MCP servers removed (open question 1 below).
- Checked with no model: `nix fmt -- --ci`; the desktop home generation builds; its
  `~/.claude/agents/*.md` and `settings.json` hold the expected tool lists and plugin flags.
- Not checked: a live `/ship` run, and Claude Code loading the new agents in a session.
- Decision (the person, 2026-10-25): make it, judge it on real `/ship` runs.
- Watch for: questions now asked mid-build in the main session, and the main session's
  context filling up on large builds (the reason the build had moved to a subagent, nixos#221).

## Open questions for owners

1. ~~Remove the duplicate MCP servers before the baseline?~~ Done with item 1: the
   official playwright and context7 plugins are on only where `mcp.nix` does not run
   that server (the server profile keeps them), and the hand-added `nixos` entry is gone
   from `~/.claude.json` on the desktop and the dev-vm.
2. Under `/ship`, which wins: AGENTS.md's short-answer style, or `/ship`'s full final report?
3. Should a typed `/code-review` and `/simplify` run this repo's skills or Claude Code's
   built-ins, and is the code-simplifier plugin still wanted?
4. The eval runs `/ship` in Claude Code only. The skills are shared with pi, whose `/ship`
   changes with every item and is not measured. Accept that, or add pi runs?
5. `/implement` on its own also dispatches code-review and simplify. Apply items 2 and 5
   there too? Recommended: yes, so the two skills do not drift.

## Left as it is, and why

- `/requirement`: already runs in the main session with the user.
- `questions`: a skill the main session loads; no context of its own.
- No row is `keep`: no subagent talks to the user itself, and no subagent is owned by someone else.
