---
name: code-review
description: Review the current diff, or a PR number/branch/path target, for correctness bugs (plus reuse/simplification/efficiency cleanups) at the given effort level (low/medium — fewer, high-confidence findings; high→max — broader coverage, may include uncertain findings); with no level given, runs at medium. Pass --comment to post findings as inline PR comments, or --fix to apply the findings to the working tree after the review. Use when the user asks to review code, a diff, or a PR.
---

# Code Review

Ported from Anthropic's built-in Claude Code `/code-review` skill (v2.1.289), made portable: findings are reported as a JSON code block in the final message (the built-in uses an internal reporting tool), "the subagent tool" means whatever agent-spawning tool the harness provides (Agent/Task), and Claude Code-only machinery (ultra cloud review, effort-level persistence, per-finding UI status updates) is dropped.

Usage: `/code-review [low|medium|high|xhigh|max] [--fix] [--comment] [<pr#>|<branch>|<path>] [--max-findings <n>|all]`

- Arguments arrive as the user request accompanying this skill invocation.
- No effort level given: run at **medium**. Unrecognized level: ignore it, say so in one short line naming the valid levels (low, medium, high, xhigh, max), and run at **medium**.
- `--max-findings <n>` replaces the level's findings cap; `--max-findings all` removes the cap.
- Follow the recipe for the level exactly, then apply any flag appendices (`--fix`, `--comment`).

## Shared blocks

### Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead. Treat this diff as the review scope.

### Correctness angles

#### Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for
each hunk — bugs in unchanged lines of a touched function are in scope (the PR
re-exposes or fails to fix them). For every line ask: what input, state, timing,
or platform makes this line wrong? Look for inverted/wrong conditions,
off-by-one, null/undefined deref, missing `await`, falsy-zero checks,
wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

#### Angle B — removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it
enforced, then search the new code for where that invariant is re-established.
If you can't find it, that's a candidate: a removed guard, a dropped error
path, a narrowed validation, a deleted test that was covering a real case.

#### Angle C — cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and
check whether the change breaks any call site: a new precondition, a changed
return shape, a new exception, a timing/ordering dependency. Also check callees:
does a parallel change in the same PR make a call unsafe?

#### Angle D — language-pitfall specialist

Scan for the classic pitfalls of the diff's language/framework — for example:
JS falsy-zero, `==` coercion, closure-captured loop var; Python mutable default
args, late-binding closures; Go nil-map write, range-var capture; SQL injection;
timezone/DST drift; float equality. Flag any instance the diff introduces.

#### Angle E — wrapper/proxy correctness

When the PR adds or modifies a type that wraps another (cache, proxy, decorator,
adapter): check that every method routes to the wrapped instance and not back
through a registry/session/global — e.g. a caching provider holding a
`delegate` field that resolves IDs via `session.get(...)` instead of
`delegate.get(...)` will re-enter the cache or recurse. Also check that the
wrapper forwards all the methods the callers actually use.

### Cleanup angles

#### Reuse

The angles above hunt for bugs; this one and the next two hunt for cleanup in
the changed code. Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.

#### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

#### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

#### Altitude

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.

#### Conventions (agent instruction files)

Find the agent instruction files that govern the changed code: the user-level
~/.claude/CLAUDE.md and ~/.agents/AGENTS.md, the repo-root CLAUDE.md or
AGENTS.md, plus any CLAUDE.md, CLAUDE.local.md, or AGENTS.md in a directory
that is an ancestor of a changed file (a directory's instruction file only
applies to files at or below it). Read each one that exists, then check the
diff for clear violations of the rules they state.

Only flag a violation when you can quote the exact rule and the exact line
that breaks it — no style preferences, no vague "spirit of the doc"
inferences. In the finding, name the instruction file's path and quote the
rule so the report can cite it. If no instruction file applies, return
nothing for this angle.

### Cleanup finding shape

Cleanup, altitude, and conventions candidates use the same
`file`/`line`/`summary` shape; in `failure_scenario`, state the concrete
cost (what is duplicated, wasted, harder to maintain, or which
CLAUDE.md/AGENTS.md rule is broken) instead of a crash. Correctness bugs
always outrank cleanup, altitude, and conventions findings when the output
cap forces a cut.

### If the subagent tool is not available

If the subagent tool is not available in your current tool set, do not error —
perform each angle (and each verification) yourself, sequentially, in this
context. Work through every angle the recipe names yourself, in this same
context, in one pass — do not skip angles for lack of fan-out. Replace the
verify phase with: dedup near-duplicates (same defect, same location, same
reason → keep one), then re-check each remaining candidate yourself against
the diff before keeping it; drop anything you can't back up with a concrete
failure scenario. For recipes with a sweep phase, take that pass yourself too
(same context, no subagent).

State clearly in your summary that this was a single-pass review done without
the subagent tool, not the full multi-agent fan-out, so whoever reads
it isn't misled about what actually ran.

### Output contract

Return findings as a JSON array of at most the level's cap (or, with
`--max-findings all`, one object for every finding that survives, no maximum):

```json
[
  {
    "file": "path/to/file.ext",
    "line": 123,
    "summary": "one-sentence statement of the bug",
    "failure_scenario": "concrete inputs/state → wrong output/crash"
  }
]
```

Ranked most-severe first. If more than the cap survive, keep the most
severe. If nothing survives verification, return `[]`.

## Recipes

### low — `low effort → 1 diff pass → no verify → ≤4 findings`

#### Turn 1 — read

One tool call: read the unified diff (`git diff @{upstream}...HEAD; git diff HEAD`
to cover both committed and uncommitted changes, or `git diff main...HEAD` /
the target passed as an argument). Skip test/fixture
hunks (`test/`, `spec/`, `__tests__/`, `*_test.*`, `*.test.*`,
`fixtures/`, `testdata/`) — test-file changes are not reviewed at this level.
No subagents, no full-file reads.

#### Turn 2 — findings

Flag runtime-correctness bugs visible from the hunk alone: inverted/wrong
condition, off-by-one, null/undefined deref where adjacent lines show the value
can be absent, removed guard, falsy-zero check, missing `await`,
wrong-variable copy-paste, error swallowed in a catch that should propagate.
Also flag — still from the hunk alone — new code that duplicates an existing
helper visible in the diff context, and dead code the diff leaves behind.

Do **not** flag style, naming, perf, missing tests, or anything outside the
hunk.

Output at most **4 findings**, most-severe first, one line each:
`path/to/file.ext:123 — what's wrong and the concrete failure`. If nothing
qualifies, output exactly `(none)`.

### medium (default) — `medium effort → 3+5 angles × 6 candidates → 1-vote verify → ≤8 findings`

You are reviewing for **precision** at medium effort: every finding you surface
should be one a maintainer would act on.

Phase 0.

#### Phase 1 — Find candidates (3 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 6 each)

Run **8 independent finder angles** via the subagent tool: correctness angles
A, B, and C, then Reuse, Simplification, Efficiency, Altitude, and Conventions
from the shared blocks. Each surfaces **up to 6 candidate findings** with
`file`, `line`, a one-line `summary`, and a concrete `failure_scenario`. (No
subagent tool → see the shared fallback block.)

The cleanup finding shape applies to the non-correctness angles.

Pass every candidate with a nameable failure scenario through — finders that
silently drop half-believed candidates bypass the verify step and are the
dominant cause of misses.

#### Phase 2 — Verify (1-vote, 3-state)

Dedup candidates that point at the same line/mechanism, keeping the one with
the most concrete failure scenario. For each remaining candidate, run **one
verifier** via the subagent tool: give it the diff, the relevant
file(s), and the candidate, and have it return exactly one of:

- **CONFIRMED** — can name the inputs/state that trigger it and the wrong
  output or crash. Quote the line.
- **PLAUSIBLE** — mechanism is real, trigger is uncertain (timing, env,
  config). State what would confirm it.
- **REFUTED** — factually wrong (code doesn't say that) or guarded elsewhere.
  Quote the line that proves it.

Keep candidates where the vote is CONFIRMED or PLAUSIBLE.

#### Output

Per the output contract, at most **8 findings**.

### high — `high effort → 3+5 angles × 6 candidates → 1-vote verify (recall-biased) → ≤10 findings`

You are reviewing for **recall** at high effort: catch every real bug a careful
reviewer would catch in one sitting. At this level, catching real bugs matters
more than avoiding false positives. Err on the side of surfacing.

Phase 0, then the same Phase 1 as medium (8 finder angles, up to 6 candidates
each, same fallback), then:

#### Phase 2 — Verify (1-vote, recall-biased)

Dedup near-duplicates (same defect, same location, same reason → keep one). For
each remaining candidate, run **one verifier** via the subagent tool:
give it the diff, the relevant file(s), and the candidate; it returns exactly
one of **CONFIRMED / PLAUSIBLE / REFUTED**.

**PLAUSIBLE by default** — do not refute a candidate for being "speculative" or
"depends on runtime state" when the state is realistic: concurrency races,
nil/undefined on a rare-but-reachable path (error handler, cold cache, missing
optional field), falsy-zero treated as missing, off-by-one on a boundary the
code does not exclude, retry storms / partial failures, regex/allowlist that
lost an anchor. These are PLAUSIBLE.

**REFUTED** only when constructible from the code: factually wrong (quote the
actual line); provably impossible (type/constant/invariant — show it); already
handled in this diff (cite the guard); or pure style with no observable effect.

Keep **CONFIRMED and PLAUSIBLE**. Drop REFUTED.

#### Output

Per the output contract, at most **10 findings**.

### xhigh — `xhigh effort → 5+5 angles × 8 candidates → 1-vote verify → sweep → ≤15 findings`

You are reviewing for **recall** at extra-high effort: catch every real bug. At
this level, catching real bugs matters more than avoiding false positives — a
missed bug ships. Err on the side of surfacing.

Phase 0.

#### Phase 1 — Find candidates (5 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 8 each)

Run **10 independent finder angles** via the subagent tool: correctness angles
A through E, then Reuse, Simplification, Efficiency, Altitude, and Conventions
from the shared blocks. Each surfaces **up to 8 candidate findings**. Do NOT
let one angle's conclusions suppress another's — if two angles flag the same
line for different reasons, record both. (No subagent tool → see the shared
fallback block.)

The cleanup finding shape applies to the non-correctness angles.

#### Phase 2 — Verify (1-vote, 3-state)

Same verifier protocol as medium (CONFIRMED / PLAUSIBLE / REFUTED; keep
CONFIRMED and PLAUSIBLE).

This is recall mode — a single non-REFUTED vote carries the finding. Do NOT
drop on uncertainty.

#### Phase 3 — Sweep for gaps

Run **one more finder** as a fresh reviewer who has the verified list. Re-read
the diff and enclosing functions looking ONLY for defects not already listed.
Do not re-derive or re-confirm anything already there — the job is gaps. Focus
on what the first pass tends to miss: moved/extracted code that dropped a guard
or anchor; second-tier footguns (dataclass default evaluated once, `hash()`
non-determinism, lock-scope shrink, predicate methods with side effects);
setup/teardown asymmetry in tests; config defaults flipped.

Surface **up to 8 additional candidates**, each naming a defect not already on
the list. If nothing new, return an empty sweep — do not pad.

#### Output

Per the output contract, at most **15 findings**.

### max — `max effort → 5+5 angles × 8 candidates → 1-vote verify → sweep → ≤15 findings`

Identical to xhigh, except the lead-in reads "You are reviewing for **recall**
at maximum effort" — catch every real bug. At this level, catching real bugs
matters more than avoiding false positives — a missed bug ships. Err on the
side of surfacing.

## Flag appendices

### Applying fixes (--fix)

The `--fix` flag was passed. After producing the findings list, apply the
findings to the working tree instead of stopping at the report: fix each one
directly — correctness bugs and reuse/simplification/efficiency cleanups alike.
Skip any finding whose fix would change intended behavior, require changes well
outside the reviewed diff, or that you judge to be a false positive — note the
skip rather than arguing with it. Finish with a brief summary of what was fixed
and what was skipped.

### Posting to GitHub (--comment)

The `--comment` flag was passed. After producing the findings list, if the
review target is a GitHub PR, post each finding as an inline PR comment via
`mcp__github_inline_comment__create_inline_comment` (one call per finding;
include a suggestion block only when it fully fixes the issue). If that tool
is not available in this session, fall back to `gh api` (repos/{owner}/{repo}/pulls/{pr}/comments)
or print the findings instead. If the target is not a PR, print the findings
to the terminal and note that `--comment` was ignored.

### Posting to GitLab (--comment)

The `--comment` flag was passed. After producing the findings list, if the
review target is a GitLab merge request, post the findings as one general MR
note via `glab mr note <mr> -m "<body>"` from inside that project's checkout
(every finding with its file:line, the issue, and the suggested fix). glab has
no single verb for line-anchored comments; those require
`glab api projects/:id/merge_requests/:iid/discussions`, so post the general
note unless the user asks for inline threads. If glab is not available in this
session, print the findings instead. If the target is not an MR, print the
findings to the terminal and note that `--comment` was ignored.
