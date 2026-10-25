---
name: ship
description: Drive the whole workflow — /requirement, /implement, independent verification, /verify's end-user tests, and the PR — in one session, stopping for the user only where their decision is needed. Pass --critical to add a requirement-vs-implementation check. Only use when the user explicitly runs the /ship command; never trigger on your own.
disable-model-invocation: true
---

# Ship

This skill is the conductor. It runs `/requirement` and `/implement` back to back, adds independent checks after them, tests the result as its end user would with `/verify`, and opens the PR only after the final validation and `/verify` pass. `/implement` runs in this session, so its questions go straight to the user and each fix is made where the code was read; its review and simplify passes, and every check after it, run in fresh subagents. The user is pulled in only for decisions that are theirs: requirement questions, `/implement`'s questions, and failures that retries could not fix.

Usage: `/ship [--critical] [<fuzzy requirement> | <goal>]`

Four rules hold the whole skill up. Everything below is detail.

1. **The stage skills do the work.** `/ship` never re-implements a stage. Each stage — or the subagent running it — reads its skill file and follows it in full, except where this skill overrides the handoff.
2. **Checks run in fresh subagents.** A checker never saw how the work was done. Its only inputs are the documents and the code, and the requirement is its source of truth. It reports; it never fixes.
3. **Only this session spawns subagents and talks to the user.** Subagents cannot reliably start their own, and cannot reach the user, so every dispatch and every question runs here, in the main session.
4. **No PR before the final validation and `/verify` pass.**

## The pipeline

```
1. requirement      main session, with the user
2. implement        main session; review and simplify in subagents
   ↳ gate           main session, after every code change
3. impl check       [--critical] subagent
4. final validation always, subagent
5. verify           always, subagent
6. PR               main session
```

## Running a stage

The stage skills are user-invocable only, so do not call them through a skill tool. Read the skill file and follow it: `~/.agents/skills/<name>/SKILL.md` (Claude Code: `~/.claude/skills/<name>/SKILL.md`).

Overrides while `/ship` drives:

- **Skip every "Handing off to the next step" section.** Do not tell the user to run the next command or copy it to the clipboard; move straight to the next stage.
- **`/implement` runs in this session** (see stage 2 below) and stops after its Simplify step. Its Finish step (PRs and the report) is replaced by stages 3–6 here.
- **`/verify` runs in a subagent** (see stage 5 below) and skips its Finish handoff. It cannot reach the user, so it returns its questions to this session instead of asking.

### Resuming

When the argument names an existing goal (a directory under `.goals/`, or a ticket), start at the first stage that is not finished:

- No requirement → stage 1.
- No commits on the goal's branch yet → stage 2, from the build. The decisions file records what was already decided; do not re-ask it.
- Commits but no simplify pass yet → stage 2, from `/implement`'s first unfinished step (the `code-review/` files show whether review and fixes are done).
- Otherwise → the first check without a PASS report newer than the latest commit: in `verification/` for stages 3–4, in `verify/` for stage 5 (a report with no FAIL counts as a PASS).

Never redo a finished stage unless a check sends work back to it.

## Subagents

Dispatch each subagent as its named agent: pi's `subagent` tool, or Claude Code's Agent tool, with the agent's name. Where the environment does not have that agent, use a general-purpose agent given its rules (`~/.pi/agent/agents/<agent>.md`, or restated in the brief when that file is absent). Every check's brief names the goal, where the requirement and the decisions file live (paths or ticket), the branch, and where to write the report. If the environment has no subagent capability, run the check in this session, say so in the report, and tell the user the check was not independent.

Stage 2's review and simplify subagents are dispatched as `/implement` says.

| Subagent         | Agent               | Writes files?               |
| ---------------- | ------------------- | --------------------------- |
| code review      | `code-reviewer`     | no                          |
| simplify         | `worker`            | yes                         |
| impl check       | `verifier`          | report only                 |
| final validation | `verifier`          | report only                 |
| verify           | `acceptance-tester` | report and screenshots only |

Every check writes its report to `.goals/<goal>/verification/<n>-<check>.md` (`<check>` is `impl-check` or `final-validation`), where `<n>` is one higher than the highest number already in that directory. Each run gets its own file; earlier files are never edited. `.goals/` is local working state, never committed: before writing anything under it, create `.goals/.gitignore` containing `*` if it is missing, so git ignores the directory in every checkout.

```markdown
# <Check> <n> — <goal>

- **Date:** <date>
- **Verdict:** PASS | FAIL
- **Checked by:** subagent (or: in-session fallback)

## Coverage

| Requirement item | Evidence                             | Result      |
| ---------------- | ------------------------------------ | ----------- |
| <item, verbatim> | <file:line / command and its output> | PASS / FAIL |

## Problems

### 1. <one-sentence summary>

- **Kind:** missing | contradicts | out of scope | broken
- **Detail:** <what is wrong and where>
```

The verdict is FAIL when any row fails or any problem is listed.

### 2. Implement — in this session

Follow `/implement` steps 1–9 here: load the goal, analyze, decide, set up the workspace, implement, validate, review, fix, simplify. Its review (step 7) and simplify (step 9) run in subagents, as `/implement` says; the rest runs in this session.

Ask `/implement`'s questions as its Decide step says, one at a time, following the `questions` skill. An answer that follows from what the user said in the requirement conversation needs no question. A question that unravels the requirement goes back through `/requirement` here instead. Question rounds do not count as retries.

#### Gate — after every code change

Run `/implement`'s Validate step as the gate every time `/implement` says to run or rerun it, and after every fix in stages 3–5, before dispatching anything else:

- `git status --porcelain` is empty on the goal's branch.
- Every mechanical check passes: the formatter in check mode, linters, type checks, unit tests and the build, found as Validate says. Run each with its output appended to `.goals/<goal>/verification/gate.log` and read its exit code; read the log only for a command that failed, so passing output stays out of this session's context.

On a failure, fix it here and run the gate again. Gate rounds count against the Retries limit of the stage that triggered them. No check (stages 3–5) is dispatched while the gate is red: formatting, lint and unit failures are fixed here, not discovered by the final validation.

### 3. Implementation check — `--critical` only

Brief: read the requirement, the decisions file, and the full diff from the base branch. For every item under Requirements, Acceptance criteria and Constraints, point to the code that delivers it. Flag items that are missing or only partly done, behavior that contradicts an item or a recorded decision, and changes that serve no item or touch anything under Out of scope. Read the code; running it is the final validation's job.

On FAIL: fix the problems here and run the gate, then run the check again.

### 4. Final validation — always

Brief: prove the change works by running it, not by reading it. On the goal's branch, run every acceptance criterion in the requirement as an observable check, plus the project's formatter, linters, type checks, tests and builds. Record each command and the part of its output that proves the result. Anything that cannot be run here (needs hardware, a reboot, a deploy, a credential) is reported as NOT RUN with the reason; it is never assumed to pass.

On FAIL: fix the problems here and run the gate, then run the check again. NOT RUN items do not block the PR, but they are listed in it.

### 5. Verify — always

Run `/verify` in a fresh subagent as the `acceptance-tester` agent. It drives a browser and a terminal, which the `verifier` agent's tools do not allow. Brief: the goal, where the requirement and the decisions file live, the branch, the path to `/verify`'s skill file (`~/.agents/skills/verify/SKILL.md`), and every answer the user has given for this goal so far. It follows the skill in full and writes its report and screenshots under `.goals/<goal>/verify/`, not `verification/`.

The subagent cannot reach the user. When it needs something only the user can answer (how to run the app, credentials, what correct looks like), it stops and returns the questions instead of guessing. Ask them here, following the `questions` skill, save each answer as `/verify`'s Remembering section says, then dispatch a new verify subagent with the answers in its brief. Hand credentials over as environment variables in the brief, never in a file. Question rounds do not count as retries.

On FAIL: fix the problems here, run the gate, run the final validation again (its PASS predates the fix), then run `/verify` again. NOT RUN tests do not block the PR, but they are listed in it.

## Retries

Each check gets at most 2 fix-and-recheck rounds. Still failing after that → stop and show the user the latest report, then ask how to continue, following the `questions` skill. Never weaken a check, edit a report, or drop a requirement item to get a PASS.

## 6. PR

Follow `/implement`'s Finish rules for how many PRs to open. Each PR description links the requirement, lists the decisions the user made, lists the checks that ran with their verdicts, and lists every NOT RUN item of the final validation. `/verify`'s results stay out of the description, which would go stale the next time `/verify` runs: once each PR exists, post its branch's final `/verify` report on it with `publish.py --pr <url>`, as `/verify`'s "Post it on the PR" step describes. That comment carries the tests, the screenshots and the NOT RUN tests, and replaces the comment of any earlier run.

Report to the user: what was built, the verdict of every check and how many rounds each took, review findings fixed vs skipped, what simplify changed, NOT RUN items, the `/verify` report path and its PR comment URL, then the PRs as a list — one bullet per PR with its title and URL. Then open the final `/verify` report in the browser by running `~/.agents/skills/verify/scripts/report.py` on its `<n>-report.json`.

## Never

- Never run unless the user explicitly invoked this skill.
- Never skip the final validation or `/verify`, with or without `--critical`.
- Never dispatch a check while the gate is red.
- Never let a checker fix what it checks, or see the conversation that produced the work.
- Never open a PR while a check is failing.
- Never claim a check passed that did not run.
- Never edit or delete an earlier verification report.
