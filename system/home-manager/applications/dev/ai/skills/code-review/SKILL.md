---
name: code-review
description: Review a code diff, commit range, branch, change request, or file path for correctness bugs and high-value reuse, simplification, efficiency, and maintainability issues. Supports configurable review effort, optional fixes, and optional review comments.
---

# Code Review

Review the requested code changes for concrete defects and, at higher effort levels, valuable cleanup opportunities. Use the tools available in the current environment; do not assume a specific coding agent, repository host, or subagent implementation.

## Usage

`/code-review [low|medium|high|xhigh|max] [--fix] [--comment] [<change-request>|<branch>|<commit-range>|<path>] [--max-findings <n>|all]`

Arguments are supplied with the skill invocation. With no effort level, use `medium`. If the effort level is unrecognized, briefly state the valid levels (`low`, `medium`, `high`, `xhigh`, `max`) and continue at `medium`. `--max-findings <n>` overrides the tier's finding cap; `--max-findings all` removes the cap.

Run the selected tier's workflow, then apply the requested `--fix` and/or `--comment` behavior. Do not claim to have run tools, tests, agents, or integrations that were unavailable.

## Shared workflow

### Phase 0 — Establish review scope

1. Resolve the explicit target first. For a change request or merge request, use available repository-host tools when possible. For a branch, commit range, or path, inspect the relevant repository state directly.
2. If no target is supplied, compare the current branch with its configured upstream or an appropriate project base branch. Use the available repository metadata to choose the base; do not assume a particular branch name when another is clearly configured.
3. Include uncommitted changes in scope when present. In a Git repository, inspect the base-to-HEAD diff and the working-tree diff (including staged and unstaged changes as appropriate). If the selected committed range is empty, still check for working-tree changes.
4. Treat the resulting diff as the primary scope. Read surrounding code as needed to verify behavior. For explicit path targets, focus the review on that path and its relevant changes.
5. If the target or repository state cannot be resolved, report the limitation and review the material that is available rather than inventing a diff.

### Correctness angles

#### Angle A — Line-by-line diff scan

Read every relevant hunk. Read the enclosing function or unit for each hunk; defects in unchanged lines of a modified unit are in scope when the change exposes or fails to address them. Ask what input, state, timing, configuration, or platform could make each changed line fail. Look for wrong or inverted conditions, boundary errors, nullable-value dereferences, missing asynchronous waits, falsy-value checks, copy/paste mistakes, swallowed errors, and incorrectly escaped regular expressions.

#### Angle B — Removed-behavior audit

For every deleted or replaced line, identify the invariant or behavior it enforced. Search the new implementation for where that behavior is preserved. Treat a removed guard, dropped error path, weakened validation, or deleted test that covered a real case as a candidate defect unless the change intentionally and safely replaces it.

#### Angle C — Cross-component tracing

For each changed function or interface, find relevant callers and callees. Check whether the change breaks call sites through new preconditions, changed return shapes, new exceptions, altered timing or ordering, or inconsistent parallel changes. Follow the path far enough to ground a concrete failure scenario.

#### Angle D — Language and framework pitfalls

At higher effort levels, check known pitfalls of the language, runtime, framework, database, and platform. Examples include JavaScript falsy-zero checks, coercive equality, closure-captured loop variables; Python mutable defaults and late-binding closures; Go nil-map writes and range-variable capture; SQL injection; timezone or daylight-saving drift; and floating-point equality. Flag only instances introduced, exposed, or left unresolved by the change.

#### Angle E — Wrapper and proxy correctness

At higher effort levels, inspect changed wrappers such as caches, proxies, decorators, adapters, and providers. Confirm that methods route through the wrapped instance rather than recursively returning through a registry, session, or global; that delegation avoids accidental recursion; and that all methods used by callers are correctly forwarded.

### Cleanup angles

#### Reuse

Look for new code that reimplements behavior already available in the codebase. Search shared utilities and nearby modules, then name the existing helper or abstraction that should be reused.

#### Simplification

Look for unnecessary complexity introduced by the change: redundant or derivable state, duplicated logic with minor variations, deep nesting, or dead code. State a simpler form that preserves the required behavior.

#### Efficiency

Look for wasted work introduced by the change: redundant computation or I/O, independent operations performed sequentially, work added to startup or hot paths, and avoidable allocation. Check long-lived objects created from closures or captured environments that retain unnecessarily large scopes; prefer a structure that retains only the fields it needs. Name a concrete cheaper alternative.

#### Altitude

Check whether the change fixes the root cause at the correct layer rather than patching one symptom. Special cases added to shared infrastructure may indicate that the general mechanism should be corrected instead. Recommend a deeper fix only when the code supports that conclusion.

#### Conventions and instructions

Discover the instruction files that apply to the changed code, based on the current environment and repository. These may include user-level or repository-level agent instructions, scoped instructions in ancestor directories, or explicit project contribution rules. Read applicable files and respect their scope.

Flag a convention violation only when you can identify both the exact rule and the exact changed line that breaks it. Name the instruction file and quote the relevant rule in the finding. Do not report subjective style preferences or infer unwritten rules. If no relevant instructions exist, produce no findings for this angle.

### Finding quality and ranking

Every finding must identify a specific location and a plausible, concrete consequence. Correctness bugs outrank cleanup, altitude, and convention findings when the cap forces a cut. Rank findings by severity, likelihood, and impact, with the most important first. Deduplicate findings that describe the same defect and mechanism.

Use this shape for each finding:

```json
{
  "file": "path/to/file.ext",
  "line": 123,
  "summary": "One-sentence statement of the issue",
  "failure_scenario": "Concrete input or state -> incorrect output, failure, or maintenance cost"
}
```

Return findings as a JSON array. Respect the selected tier's cap unless `--max-findings` overrides it. Return `[]` when no finding survives the applicable review and verification rules. Do not invent line numbers; use the most relevant changed line when the defect spans multiple lines.

### When agent fan-out is unavailable

If the environment has no subagent or parallel-review capability, perform the required angles sequentially in the current context; do not skip angles merely because fan-out is unavailable. For verification, deduplicate near-duplicates, re-check each candidate against the diff and surrounding code, and remove any candidate that lacks a concrete, supported failure scenario. Perform the sweep when the selected tier requires one.

When using this fallback, state in the review summary that the review was performed as a single-pass review without multi-agent fan-out. Do not imply that multiple independent reviewers ran.

## Effort tiers

### low

**Goal:** High-confidence defects visible directly from the diff. **Cap:** 4 findings.

1. Read the unified diff in one pass, including relevant staged and unstaged changes. Skip test and fixture changes at this tier, including common test/spec/fixture directories and test-file naming patterns.
2. Do not read full files or use subagents.
3. Report only runtime-correctness defects apparent from the hunk, such as a wrong condition, boundary error, an unguarded absent value evident in context, a removed guard, a falsy-zero check, a missing asynchronous wait, an incorrect variable, a swallowed error, duplicated helper logic visible in the diff, or newly stranded dead code.
4. Do not report style, naming, performance, missing tests, or issues requiring evidence outside the hunk.
5. Return at most 4 findings, most severe first. Use the standard JSON-array format; return `[]` if none qualify.

### medium — default

**Goal:** Precision; each finding should be actionable. **Cap:** 8 findings.

**Phase 1 — Candidate discovery:** Use 8 independent review passes when multi-agent tools are available: correctness angles A, B, and C; plus Reuse, Simplification, Efficiency, Altitude, and Conventions. Each pass may propose up to 6 candidates. Preserve candidates with a concrete failure scenario for verification rather than silently discarding uncertain ones.

**Phase 2 — Verification:** Deduplicate candidates that point to the same defect or mechanism. For each remaining candidate, use one independent verifier when available. The verifier must return exactly one status:

- **CONFIRMED** — the inputs or state that trigger the defect and the resulting wrong behavior or crash are identifiable; cite the relevant line.
- **PLAUSIBLE** — the mechanism is real, but the trigger depends on runtime, timing, environment, or configuration; state what would confirm it.
- **REFUTED** — the claim is factually incorrect or a guard already prevents it; cite the line that proves this.

Keep **CONFIRMED** and **PLAUSIBLE** candidates; drop **REFUTED** candidates. If independent verification is unavailable, perform the same check yourself and disclose the single-pass fallback.

Return at most 8 findings.

### high

**Goal:** Recall; catch the real defects a careful reviewer could find in one sitting. Favor finding real bugs over minimizing false positives. **Cap:** 10 findings.

Run Phase 0 and the same candidate-discovery process as `medium`, using the same 8 review passes and up to 6 candidates per pass. Verify each deduplicated candidate using the same three statuses as `medium`.

In this tier, treat realistic but uncertain failure states as **PLAUSIBLE**, including concurrency races, rare-but-reachable null or undefined values, falsy-zero handling, boundary errors not excluded by the code, retry storms, partial failures, and weakened regular-expression or allowlist anchors. Refute a candidate only when the code provides evidence that it is factually wrong, impossible due to a type/constant/invariant, already handled by a guard, or has no observable effect.

Keep **CONFIRMED** and **PLAUSIBLE** findings. Return at most 10.

### xhigh

**Goal:** Extra-high recall. **Cap:** 15 findings.

**Phase 1 — Candidate discovery:** Use 10 independent review passes when available: correctness angles A through E; plus Reuse, Simplification, Efficiency, Altitude, and Conventions. Each pass may propose up to 8 candidates. Do not suppress one pass's candidate because another pass reached a different conclusion. Record different defect mechanisms separately, then deduplicate only true duplicates.

**Phase 2 — Verification:** Verify each deduplicated candidate using the `CONFIRMED` / `PLAUSIBLE` / `REFUTED` protocol. This is recall-oriented: keep any candidate not refuted by evidence.

**Phase 3 — Gap sweep:** Use one fresh review pass with access to the verified findings. Re-read the diff and enclosing code only to find defects not already listed. Look especially for moved or extracted code that lost a guard or anchor; less-common language pitfalls; reduced lock scope; side effects in predicate methods; setup/teardown asymmetry; and flipped configuration defaults. Return up to 8 additional candidates from this sweep, without padding the list when no new issue is found.

Return at most 15 findings.

### max

Use the same workflow, candidate counts, verification policy, gap sweep, and 15-finding cap as `xhigh`. Make the review's recall objective explicit: missing a real defect is more costly than including a well-grounded plausible finding.

## Optional flags

### `--fix`

After reviewing the findings, apply valid fixes directly to the working tree. Fix correctness defects and worthwhile reuse, simplification, or efficiency issues. Do not apply a fix if it would change intended behavior, reach well beyond the review scope, or address a finding you judge to be false. Summarize which issues were fixed and which were skipped, with reasons. Do not claim tests passed unless they were actually run; run relevant tests when practical and available.

### `--comment`

If the target is a hosted code-review request and a compatible provider integration is available, publish each finding as an inline comment when supported. If only general review comments are supported, post a consolidated comment containing each finding's file, line, issue, and suggested fix. Include a suggestion patch only when it fully and safely resolves the issue.

If the target is not a hosted review request, or no compatible integration is available, do not pretend comments were posted. Report the findings normally and briefly state why comment posting was skipped. Use the platform's available tools or CLI rather than assuming a specific hosting provider or command.
