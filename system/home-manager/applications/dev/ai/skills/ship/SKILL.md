---
name: ship
description: Drive the whole workflow — /requirement, /plan, /implement, independent verification, and the PR — in one session, stopping for the user only where their decision is needed. Pass --critical to add requirement-vs-plan and requirement-vs-implementation checks. Only use when the user explicitly runs the /ship command; never trigger on your own.
disable-model-invocation: true
---

# Ship

This skill is the conductor. It runs `/requirement`, `/plan` and `/implement` back to back, adds independent checks between them, and opens the PR only after a final validation passes. `/implement` runs in subagents, so its code, diffs and command output stay out of this session's context. The user is pulled in only for decisions that are theirs: requirement questions, planning questions, and failures that retries could not fix.

Usage: `/ship [--critical] [<fuzzy requirement> | <goal>]`

Four rules hold the whole skill up. Everything below is detail.

1. **The stage skills do the work.** `/ship` never re-implements a stage. Each stage — or the subagent running it — reads its skill file and follows it in full, except where this skill overrides the handoff.
2. **Checks run in fresh subagents.** A checker never saw how the work was done. Its only inputs are the documents and the code, and the requirement is its source of truth. It reports; it never fixes.
3. **Only this session spawns subagents.** Subagents cannot reliably start their own, so every stage that dispatches one runs here, in the main session.
4. **No PR before the final validation passes.**

## The pipeline

```
1. requirement      main session, with the user
2. plan             main session, with the user when a planning question is needed
3. plan check       [--critical] subagent
4. implement        subagents: build, review, fix, simplify
   ↳ gate           main session, after every code-changing subagent
5. impl check       [--critical] subagent
6. final validation always, subagent
7. PR               main session
```

## Running a stage

The stage skills are user-invocable only, so do not call them through a skill tool. Read the skill file and follow it: `~/.agents/skills/<name>/SKILL.md` (Claude Code: `~/.claude/skills/<name>/SKILL.md`).

Overrides while `/ship` drives:

- **Skip every "Handing off to the next step" section.** Do not tell the user to run the next command or copy it to the clipboard; move straight to the next stage.
- **`/implement` runs as a chain of subagents** (see stage 4 below) and stops after its Simplify step. Its Finish step (PRs and the report) is replaced by stages 5–7 here.

### Resuming

When the argument names an existing goal (a directory under `.agent/goals/`, or a ticket), start at the first stage that is not finished:

- No requirement → stage 1. No plan → stage 2.
- No commits on the goal's branch yet → stage 3 (stage 4 without `--critical`).
- Commits but no simplify pass yet → stage 4, dispatching the subagent for `/implement`'s first unfinished step (the `code-review/` files show whether review and fixes are done).
- Otherwise → the first check without a PASS report in `verification/` that is newer than the latest commit.

Never redo a finished stage unless a check sends work back to it.

## Subagents

Dispatch each check with whatever the environment offers: pi's `subagent` tool with the named agent, or Claude Code's Agent tool with a general-purpose agent, given the rules from the `verifier` agent (`~/.pi/agent/agents/verifier.md`, or restated in the prompt when that file is absent) and the brief below. Every brief names the goal, where the requirement and plan live (paths or ticket), the branch, and where to write the report. If the environment has no subagent capability, run the check in this session, say so in the report, and tell the user the check was not independent.

Stage 4's subagents (build, fix, simplify) are dispatched the same way with the `worker` agent, or a general-purpose agent in Claude Code; code review uses `code-reviewer`. If the environment has no subagent capability, run stage 4 in this session and say so.

| Subagent         | pi agent        | Writes files? |
| ---------------- | --------------- | ------------- |
| build            | `worker`        | yes           |
| code review      | `code-reviewer` | no            |
| fix              | `worker`        | yes           |
| simplify         | `worker`        | yes           |
| plan check       | `verifier`      | report only   |
| impl check       | `verifier`      | report only   |
| final validation | `verifier`      | report only   |

Every check writes its report to `.agent/goals/<goal>/verification/<n>-<check>.md` (`<check>` is `plan-check`, `impl-check` or `final-validation`), where `<n>` is one higher than the highest number already in that directory. Each run gets its own file; earlier files are never edited.

```markdown
# <Check> <n> — <goal>

- **Date:** <date>
- **Verdict:** PASS | FAIL
- **Checked by:** subagent (or: in-session fallback)

## Coverage

| Requirement item | Evidence                                         | Result      |
| ---------------- | ------------------------------------------------ | ----------- |
| <item, verbatim> | <plan step / file:line / command and its output> | PASS / FAIL |

## Problems

### 1. <one-sentence summary>

- **Kind:** missing | contradicts | out of scope | broken
- **Detail:** <what is wrong and where>
```

The verdict is FAIL when any row fails or any problem is listed.

### 3. Plan check — `--critical` only

Brief: read the requirement and the plan. For every item under Requirements, Acceptance criteria and Constraints, find the plan step that delivers it and the Verification entry that proves it. Flag items with no step, steps that contradict an item, steps that serve no item or touch anything under Out of scope, and acceptance criteria with no Verification entry. Do not judge how good the design is; only whether it fits.

On FAIL: revise the plan following the `/plan` skill (a requirement gap goes back to the user as its Type 3 question), get the user's confirmation of the changed parts, then run the check again.

### 4. Implement — in subagents

Run `/implement` as the chain below, one subagent at a time, each dispatched from this session. Every brief names the goal, where the requirement and plan live, the branch, the path to `/implement`'s skill file (`~/.agents/skills/implement/SKILL.md`), and the steps of it to follow — and tells the subagent not to dispatch subagents of its own. This session reads each subagent's report, not the diff.

1. **Build** (`worker`): `/implement` steps 1–4 — load the goal, set up the workspace, implement, validate. Reports the branch, the commits, the validation results, and the project's mechanical check commands (formatter in check mode, linters, type checks, unit tests, build) for the gate. If a plan step cannot be executed, it stops and reports the contradiction; take that to the user and back through `/plan` here, then dispatch a new build for the remaining steps.
2. **Review** (`code-reviewer`): `/implement` step 5 on the goal's diff. This session writes the findings to the review file, as step 5 describes.
3. **Fix** (`worker`): `/implement` step 6 on that review file — fix each finding, update its entry, rerun Validate. Skip when the review found nothing.
4. **Simplify** (`worker`): `/simplify` on the goal's changes, as in `/implement` step 7, then rerun Validate.

A subagent that reports failing validation gets a fix `worker` with its report, under the Retries rules below.

#### Gate — after every code-changing subagent

A worker's "validation passed" is a claim, not proof. After every build, fix and simplify subagent — in stage 4 and in every fix round of stages 5 and 6 — run the gate in this session before dispatching anything else:

- `git status --porcelain` is empty on the goal's branch.
- Every mechanical check command from the build report passes. Run each with its output appended to `.agent/goals/<goal>/verification/gate.log` and read only exit codes here, so the output stays out of this session's context.

On a failure, dispatch a fix `worker` with the failing commands and the log path, then run the gate again. Gate rounds count against the Retries limit of the stage that triggered them. No check (stages 5–6) is dispatched while the gate is red: formatting, lint and unit failures are fixed here, not discovered by the final validation.

### 5. Implementation check — `--critical` only

Brief: read the requirement, the plan, and the full diff from the base branch. For every item under Requirements, Acceptance criteria and Constraints, point to the code that delivers it. Flag items that are missing or only partly done, behavior that contradicts an item, and changes that are out of scope or not in the plan. Read the code; running it is the final validation's job.

On FAIL: dispatch a fix `worker` with the report to fix the problems and rerun `/implement`'s Validate step, then run the check again.

### 6. Final validation — always

Brief: prove the change works by running it, not by reading it. On the goal's branch, run every Verification entry in the plan and every acceptance criterion in the requirement as an observable check, plus the project's formatter, linters, type checks, tests and builds. Record each command and the part of its output that proves the result. Anything that cannot be run here (needs hardware, a reboot, a deploy, a credential) is reported as NOT RUN with the reason; it is never assumed to pass.

On FAIL: dispatch a fix `worker` with the report to fix the problems and rerun `/implement`'s Validate step, then run the check again. NOT RUN items do not block the PR, but they are listed in it.

## Retries

Each check gets at most 2 fix-and-recheck rounds. Still failing after that → stop and show the user the latest report, then ask how to continue, following the `questions` skill. Never weaken a check, edit a report, or drop a requirement item to get a PASS.

## 7. PR

Follow `/implement`'s Finish rules for how many PRs to open. Each PR description links the requirement and plan, and lists the checks that ran with their verdicts, plus every NOT RUN item.

Report to the user: what was built, the verdict of every check and how many rounds each took, review findings fixed vs skipped, what simplify changed, NOT RUN items, then the PRs as a list — one bullet per PR with its title and URL.

## Never

- Never run unless the user explicitly invoked this skill.
- Never skip the final validation, with or without `--critical`.
- Never dispatch a check while the gate is red, or trust a worker's validation claim in place of the gate.
- Never let a checker fix what it checks, or see the conversation that produced the work.
- Never open a PR while a check is failing.
- Never claim a check passed that did not run.
- Never edit or delete an earlier verification report.
