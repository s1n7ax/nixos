---
name: simplify
description: Clean up the changed code without changing behavior — review the changed code for reuse, simplification, efficiency, and altitude cleanups, then apply the fixes. Quality only — it does not hunt for bugs; use the code-review skill for that. Use when the user asks to simplify, clean up, or reduce complexity in recently changed code.
---

# Simplify

Ported from Anthropic's built-in Claude Code `/simplify` skill (v2.1.289), made portable: "the subagent tool" means whatever agent-spawning tool the harness provides (Agent/Task), with Anthropic's own single-pass fallback when none exists.

Usage: `/simplify [<target>]`

`/simplify → 4 cleanup agents in parallel → apply the fixes`

You are improving the quality of the changed code, not hunting for bugs. Review
it for reuse, simplification, efficiency, and altitude issues, then fix what you
find. Do not look for correctness bugs — that is what `/code-review` is for.

If a target was passed as an argument, start with `Review target: \`<target>\``.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead. Treat this diff as the review scope.

## Phase 1 — Review (4 cleanup agents in parallel)

Launch **4 independent review agents** via the subagent tool, all in a
single message so they run concurrently. Pass each agent the diff and one of
the four angles below. Each returns its findings with `file`, `line`, a
one-line `summary`, and the concrete cost (what is duplicated, wasted, or
harder to maintain).

**If the subagent tool isn't available in this context**, the usual 4-agent
fan-out can't run: work through all four angles below yourself, in this same
context, in one pass — do not skip an angle for lack of fan-out.

### Reuse

Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

### Altitude

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.

## Phase 2 — Apply the fixes

Wait for all four agents to complete (or finish your single pass), dedup
findings that point at the same line or mechanism, and fix each remaining one
directly. Skip any finding whose fix would change intended behavior, require
changes well outside the reviewed diff, or that you judge to be a false
positive — note the skip rather than arguing with it. Finish with a brief
summary of what was fixed and what was skipped (or confirm the code was
already clean).

If you did a single-pass review without the subagent tool, state clearly in
your summary that this was a single-pass review, not the full 4-agent
fan-out, so whoever reads it isn't misled about what actually ran.
