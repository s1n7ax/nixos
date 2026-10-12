---
name: implement
description: Execute an implementation plan written by /plan, fulfilling the requirement documented by /requirement. After implementing, runs /code-review in a subagent, tracks findings in the goal's code-review directory, fixes them in the same session, then runs /simplify on the changes. Only use when the user explicitly runs the /implement command; never trigger on your own.
disable-model-invocation: true
---

# Implement

This skill is execution. The user arrives with a confirmed requirement and a plan another agent can execute with no questions asked — and this skill builds it, reviews it, fixes the review findings, and simplifies the result, all in one session.

Three rules hold the whole skill up. Everything below is detail.

1. **The plan is the contract.** Every decision was made at plan time. Execute the plan as written; never redesign silently. A step that proves impossible or wrong sends the plan back — it does not get improvised around.
2. **Review and fix happen in this session.** Implementation is not done when the code is written. It is done when the code review's findings are fixed and the changes have been simplified.
3. **Every finding and every fix is written down.** The review file under the goal's `code-review/` directory is the record; it is updated, never rewritten.

## Running the session

### 1. Load the goal

Resolve the `<goal>`:

- The user gave a goal name or path → use it.
- The current branch name starts with a goal directory name under `.agent/goals/` → use that goal.
- Exactly one goal under `.agent/goals/` has a plan → use it.
- Several candidates → ask which one, following the `questions` skill, and wait.
- None → tell the user to run `/requirement` and `/plan` first, and stop.

Read `.agent/goals/<goal>/requirement/requirement.md` and `.agent/goals/<goal>/plan/plan.md`. If the plan is missing, tell the user to run `/plan` first and stop. The requirement is the definition of done; the plan is how to get there. Both constrain everything that follows.

### 2. Set up the workspace

Follow the plan's branch instructions. With multiple approaches, the plan names one branch per approach (`<goal>_approach_<approach>`) — each approach is implemented on its own branch, starting from the shared Changes. With no branch named, work on a `<goal>` branch created from the project's base branch. Never commit to the user's current branch unless it is already the goal's branch.

### 3. Implement

Execute the plan's Changes in order, across every project listed, respecting the dependencies the steps declare. One step = one change; commit per logical change. With several approaches: implement the shared Changes first, then each approach in full on its branch.

When a step cannot be executed as written — the code contradicts it, a spike finding no longer holds, a dependency is missing — stop that line of work. A wrong plan is not permission to redesign: name the contradiction, tell the user the plan needs another `/plan` pass, and wait. Steps already completed stay committed; do not roll them back unless the user asks.

### 4. Validate

Before review, prove the implementation works:

- Run every check in the plan's Verification section — one per requirement item.
- Run the project's formatter, linters, type checks, tests and builds.

Fix failures and rerun until green. Never move to review with failing checks, and never claim a check passed that was not run.

### 5. Review

Run the review as a **subagent** — a fresh context reviewing the diff. Where the environment provides named subagents (pi's `subagent` tool, Claude Code's Agent tool), dispatch the `code-reviewer` agent with the changes as the target, defaulting to `medium` effort unless the user asked for another level. The subagent reviews; it never fixes. If the environment has no subagent capability, run the review in this session and say so, per the code-review skill's own fallback rule.

Write the findings to `.agent/goals/<goal>/code-review/<n>-review.md`, where `<n>` is one higher than the highest existing review number (`1-review.md` for the first). Each review round gets its own file; earlier files are never edited by later rounds.

```markdown
# Review <n> — <goal>

- **Date:** <date>
- **Scope:** <branch or diff reviewed>
- **Effort:** <level>
- **Reviewer:** code-reviewer subagent (or: in-session fallback)

## Findings

### 1. <one-sentence summary>

- **Location:** `path/to/file:line`
- **Status:** CONFIRMED | PLAUSIBLE
- **Failure scenario:** <concrete input or state -> wrong behavior>
- **Fix:** <filled in during the fix pass>

### 2. ...
```

### 6. Fix

Fix every finding in this same session, most severe first. For each one, apply the fix and update its entry in the review file — never in a separate document:

- **Fixed:** what changed and where (`- **Fix:** Fixed — <what changed, file/symbol>`).
- **Skipped:** only with a reason — the finding is false, the fix would change required behavior, or the plan forbids it (`- **Fix:** Skipped — <reason>`).

After all fixes, rerun the Validation step. A fix that breaks a check is not a fix.

### 7. Simplify

Run `/simplify` on the changes. It reviews the diff against the same requirement and plan documents, so it needs no extra briefing. Rerun Validation afterward. Simplify is quality-only; its changes need no entries in the review file.

### 8. Finish

- With approaches: one PR per project per approach, on the approach's branch, so the user can pick.
- Otherwise: one PR per project, unless the project says otherwise.
- Report: what was built, review findings fixed vs skipped, what simplify changed, validation results, then the PRs as a list — one bullet per PR with the PR title and URL, grouped by project (and by approach when there are approaches).

## Handing off to the next step

`/implement` is the last step of the workflow. After finishing, **tell the user the workflow is complete** — there is no next command to run or copy. If review or validation left unresolved work, name it explicitly instead of implying a next step.

## Never

- Never run unless the user explicitly invoked this skill.
- Never ask a question outside the `questions` skill.
- Never start without both the requirement and the plan.
- Never deviate from the plan silently — a plan that cannot be executed goes back to `/plan`.
- Never skip the review, the fix pass, or the simplify pass.
- Never mark a finding fixed without the fix applied and validation rerun.
- Never edit or delete an earlier review file.
- Never claim tests, checks, or reviews ran that did not run.
- Never expand scope beyond the plan, however tempting the nearby work.
