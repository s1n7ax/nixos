---
name: ship
description: "Drive the whole workflow — /requirement, /implement, a draft PR, green CI, independent verification and /verify's end-user tests — in one session, finishing only when the PR is mergeable, stopping for the user only where their decision is needed. Run with no argument to pick one of the unfinished local goals or open agent:ship GitHub issues; parallel runs never take the same task. Pass --critical to add a requirement-vs-implementation check. Asking for prototypes means: build a few, the user picks one, and the pick ships. Only use when the user explicitly runs the /ship command; never trigger on your own."
disable-model-invocation: true
---

# Ship

This skill is the conductor. It runs `/requirement` and `/implement` back to back, opens a draft PR, waits for its CI to go green, then runs independent checks and tests the result as its end user would with `/verify`. The run is done only when the PR can be merged. `/implement` runs in this session, so its questions go straight to the user and each fix is made where the code was read; its review and simplify passes, and every check after it, run in fresh subagents. The user is pulled in only for decisions that are theirs: requirement questions, `/implement`'s questions, and failures that retries could not fix.

Usage: `/ship [--critical] [<fuzzy requirement> | <goal> | #<issue>]`

When the user asks for prototypes — in the argument or at any point in the run — see Prototypes below.

Five rules hold the whole skill up. Everything below is detail.

1. **The stage skills do the work.** `/ship` never re-implements a stage. Each stage — or the subagent running it — reads its skill file and follows it in full, except where this skill overrides the handoff.
2. **Checks run in fresh subagents.** A checker never saw how the work was done. Its only inputs are the documents and the code, and the requirement is its source of truth. It reports; it never fixes.
3. **Only this session spawns subagents and talks to the user.** Subagents cannot reliably start their own, and cannot reach the user, so every dispatch and every question runs here, in the main session.
4. **Done means a mergeable PR.** The run ends only when, on the PR's latest commit, every CI check is green, the final validation and `/verify` passed, and the PR is out of draft. The final validation and `/verify` run only on a green PR, and waiting for CI costs no tokens (see stage 5).
5. **One task per run, in its own worktree.** Several `/ship` runs may share a repository, so each claims its task before touching it and builds it in the goal's own git worktree. Two runs never work on one task, and never switch branches under each other.

## The pipeline

```
1. requirement      main session, with the user
2. implement        main session; review and simplify in subagents
   ↳ prototypes     only when asked, after Decide; the user picks one
   ↳ gate           main session, after every code change
3. impl check       [--critical] subagent
4. draft PR         main session
5. CI               main session, waiting in the background until green
6. final validation always, subagent, on a green PR
7. verify           always, subagent, on a green PR
8. done             main session: PR ready for review and mergeable
```

Every fix after stage 4 is committed, gated and pushed, and goes back through stage 5 before any check runs again.

## Picking a task

When the argument holds no requirement, goal or issue (`--critical` alone counts as none), offer the work that is waiting and let the user pick one:

1. Run `~/.agents/skills/ship/scripts/tasks.py list` (Claude Code: `~/.claude/skills/ship/scripts/tasks.py`). It prints, numbered, the unfinished goals under `.ship/` (no open or merged PR from the goal's branch yet) and the open GitHub issues labelled `agent:ship` (no open or merged PR closes them yet), each with how far it got. Then it prints the tasks other agents hold, and any source it could not read.
2. Show the list as printed, then ask which task to work on, following the `questions` skill: with up to 3 tasks, one option per task in the ask-question tool; with more, in plain text, answered with the task's number. Ask even when only one task is listed: which work starts is the user's call. With none, say there is nothing to ship, and stop.
3. Claim the pick (see below). When another agent claimed it while the user was choosing, say so, list again, and ask again.

Never offer a task listed as taken. When the user asks for one anyway, say which agent holds it, and claim it with `--force` only once they confirm.

## Claiming the task

Every run claims its task with `tasks.py claim <task>` before working on it, and holds the claim until the run ends. `<task>` is `goal:<goal>` or `issue:<n>`. The claim is atomic: of two agents claiming one task at once, exactly one wins, and the other exits with code 2 and the holder's name. It belongs to this agent's process and frees itself when that process exits, so a crashed run never blocks a task for good. Claiming an issue also labels it `agent:shipping`, so agents on other machines skip it.

- **Picked from the list** — claim it right after the pick.
- **Named in the argument** (a goal, `#<n>`, or an issue URL) — claim it before anything else. Exit 2 → tell the user which agent holds it, and stop.
- **A new fuzzy requirement** — claim `goal:<goal>` as soon as the goal's name is chosen, before writing anything under `<goals>/<goal>/`. Exit 2 → choose another name.

Release it with `tasks.py release <task>` once the run is done (stage 8), or when the user stops the run.

## Where the work happens

`<main>` is the repository's main checkout: the first path `git worktree list --porcelain` prints. `<goals>` is `<main>/.ship`. Every `.ship/` path in this skill and in the stage skills means `<goals>/`, written out as an absolute path, so the goal's files and the claims are the same from every worktree.

Each goal is built in its own git worktree at `<goals>/<goal>/worktree`. This replaces `/implement`'s "Set up the workspace" step:

- Create it before the build: `git -C <main> worktree add -b <goal> <path> <base branch>`, or without `-b <goal>` and with `<goal>` in place of the base branch when the branch already exists. Reuse the worktree when it is already there.
- With approaches, switch between their branches inside this one worktree.
- A goal that touches other projects gets a worktree in each, at `<that project's main checkout>/.ship/<goal>/worktree`.
- `cd` into the worktree. The build, the gate and every fix run there, and every subagent's brief names the worktree as the place to read and run the code.
- When git refuses because the goal's branch is checked out in another worktree, tell the user where, and stop: switching that checkout's branch would disturb whatever is open there.
- Once the run is done (stage 8), remove it: `git -C <main> worktree remove <path>`. The branch stays.

## Issues

An issue is where a goal starts, never where its documents live: the requirement and decisions go under `<goals>/<goal>/`, as for any goal.

- The issue's goal is the directory under `<goals>/` whose `issue` file holds its number. When there is none yet, name the goal a short kebab-case description of what the issue achieves (e.g. `validate-requests`), and when creating its directory, write the issue's number to `<goals>/<goal>/issue`, so the listing and the claims treat the goal as the issue.
- When the body follows `/requirement`'s template (it has an `## Acceptance criteria` section), save it unchanged as the goal's requirement and start at stage 2. Otherwise it is the fuzzy requirement stage 1 starts from.
- Never edit the issue's body.
- Every PR's description says `Closes #<n>`, so the issue drops off the list as soon as a PR is open, and closes when it merges.

## Running a stage

The stage skills are user-invocable only, so do not call them through a skill tool. Read the skill file and follow it: `~/.agents/skills/<name>/SKILL.md` (Claude Code: `~/.claude/skills/<name>/SKILL.md`).

Overrides while `/ship` drives:

- **Skip every "Handing off to the next step" section.** Do not tell the user to run the next command or copy it to the clipboard; move straight to the next stage.
- **`/implement` runs in this session** (see stage 2 below) and stops after its Simplify step. Its "Set up the workspace" step is replaced by the goal's worktree (see Where the work happens), and its Finish step (PRs and the report) by stages 3–8 here.
- **`/verify` runs in a subagent** (see stage 7 below) and skips its Finish handoff. It cannot reach the user, so it returns its questions to this session instead of asking.

### Resuming

When the task is an existing goal (a directory under `<goals>/`, or an issue), start at the first stage that is not finished:

- No requirement under `<goals>/<goal>/` → stage 1, unless the task is an issue whose body follows the template: save it as Issues says, then go on with the next rule.
- Prototypes asked for, and `<goal>_prototype_*` branches but no pick in the decisions file → Prototypes, step 3.
- No commits on the goal's branch yet → stage 2, from the build. The decisions file records what was already decided; do not re-ask it.
- Commits but no simplify pass yet → stage 2, from `/implement`'s first unfinished step (the `code-review/` files show whether review and fixes are done).
- No PASS impl check newer than the latest commit, with `--critical` → stage 3.
- No PR from the goal's branch yet → stage 4. Commits not pushed yet → push, then stage 5.
- Otherwise → stage 5, then the first check without a PASS report newer than the latest commit: in `verification/` for stage 6, in `verify/` for stage 7 (a report with no FAIL counts as a PASS).

Never redo a finished stage unless a check sends work back to it.

## Subagents

Dispatch each subagent as its named agent: pi's `subagent` tool, or Claude Code's Agent tool, with the agent's name. Where the environment does not have that agent, use a general-purpose agent given its rules (`~/.pi/agent/agents/<agent>.md`, or restated in the brief when that file is absent). Every check's brief names the goal, where the requirement and the decisions file live, the branch and its worktree, and where to write the report. If the environment has no subagent capability, run the check in this session, say so in the report, and tell the user the check was not independent.

Stage 2's review and simplify subagents are dispatched as `/implement` says.

| Subagent         | Agent               | Writes files?               |
| ---------------- | ------------------- | --------------------------- |
| code review      | `code-reviewer`     | no                          |
| simplify         | `worker`            | yes                         |
| impl check       | `verifier`          | report only                 |
| final validation | `verifier`          | report only                 |
| verify           | `acceptance-tester` | report and screenshots only |

Every check writes its report to `.ship/<goal>/verification/<n>-<check>.md` (`<check>` is `impl-check` or `final-validation`), where `<n>` is one higher than the highest number already in that directory. Each run gets its own file; earlier files are never edited. `.ship/` is local working state, never committed: before writing anything under it, create `.ship/.gitignore` containing `*` if it is missing, so git ignores the directory in every checkout.

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

### Prototypes — only when the user asks for them

"Prototype" in a `/ship` run always means: show me a few, I pick the best, and the pick is what we ship. It is never a request to build prototypes and stop. Do not ask whether to stop after the prototypes or ship the pick — the pick ships, through every remaining stage.

Run this inside stage 2, after `/implement`'s Analyze and Decide steps and before its Implement step. In Decide, do not ask the Type 1 forks you will make the prototypes differ on; the pick settles them. Ask every other question as usual.

1. **Build 2–3 prototypes**, or as many as the user named, never more than 3. Each one takes a genuinely different direction: a different approach at a fork, or a different design for UI work. Pick the directions yourself from the analysis; ask only if the requirement leaves no basis to choose.
2. **Each prototype runs.** It is a working, unpolished build of the requirement's core, enough to judge the direction — not the final code. Build each on its own `<goal>_prototype_<name>` branch in the goal's worktree (`<name>` short kebab-case), committed. Prototypes skip review, simplify and the checks; they never get pushed or a PR.
3. **Show them.** For each: its name, what sets it apart in one line, and the evidence to judge it — screenshots for anything visual, a command and its output for a CLI or service, the key part of the diff otherwise. Send screenshots to the user where the environment allows (Claude Code: SendUserFile).
4. **Ask which one ships**, following the `questions` skill: one option per prototype in the ask-question tool. This is the only question prototypes add. A pick that combines prototypes ("A, with B's layout") is a valid answer.
5. **Make the pick the goal.** Record it in the decisions file under `## Prototypes` (each prototype in one line, and the pick with the user's reason if they gave one). Then `git checkout -B <goal> <goal>_prototype_<pick>` in the worktree, and delete the other prototype branches.
6. **Carry on with stage 2 from its Implement step**, finishing the picked prototype to production standard, then every check and the PR as usual.

### 2. Implement — in this session

Follow `/implement` steps 1–9 here: load the goal, analyze, decide, set up the workspace, implement, validate, review, fix, simplify. Its review (step 7) and simplify (step 9) run in subagents, as `/implement` says; the rest runs in this session.

Ask `/implement`'s questions as its Decide step says, one at a time, following the `questions` skill. An answer that follows from what the user said in the requirement conversation needs no question. A question that unravels the requirement goes back through `/requirement` here instead. Question rounds do not count as retries.

#### Gate — after every code change

Run `/implement`'s Validate step as the gate every time `/implement` says to run or rerun it, and after every fix in stages 3–7, before committing the fix and dispatching anything else:

- `git status --porcelain` is empty on the goal's branch.
- Every mechanical check passes: the formatter in check mode, linters, type checks, unit tests and the build, found as Validate says. Run each with its output appended to `.ship/<goal>/verification/gate.log` and read its exit code; read the log only for a command that failed, so passing output stays out of this session's context.

On a failure, fix it here and run the gate again. Gate rounds count against the Retries limit of the stage that triggered them. Nothing is pushed and no check (stages 3–7) is dispatched while the gate is red: formatting, lint and unit failures are fixed here, not discovered by CI or the final validation.

### 3. Implementation check — `--critical` only

Brief: read the requirement, the decisions file, and the full diff from the base branch. For every item under Requirements, Acceptance criteria and Constraints, point to the code that delivers it. Flag items that are missing or only partly done, behavior that contradicts an item or a recorded decision, and changes that serve no item or touch anything under Out of scope. Read the code; running it is the final validation's job.

On FAIL: fix the problems here and run the gate, then run the check again.

### 4. Draft PR

Push the goal's branch and open its PR as a draft with `gh pr create --draft`, following `/implement`'s Finish rules for how many PRs to open (one per project, or per approach). The description carries the requirement's Goal and Acceptance criteria, since the requirement file is local and reviewers cannot open it (for an issue, it also says `Closes #<n>`), and lists the decisions the user made. Stage 8 adds the checks' verdicts once they exist.

A draft keeps reviewers away while the checks run; most CI runs on drafts. When stage 5 reports no checks on a repository that has CI (a `.github/workflows/` with a `pull_request` trigger that skips drafts), mark the PR ready with `gh pr ready` and wait again.

### 5. CI — wait without spending tokens

Wait for every PR's checks with the bundled script, `~/.agents/skills/ship/scripts/pr.py` (Claude Code: `~/.claude/skills/ship/scripts/pr.py`), run in the goal's worktree:

- **Claude Code:** `pr.py wait <pr-url>` through the Bash tool with `run_in_background`, then end the turn with one line saying CI is running. The harness wakes this session when the script exits, so nothing is spent while CI runs, and the status line shows the progress (`CI #<n> running 9/14`) from the state file the script writes.
- **Without background tasks:** `pr.py wait --timeout 540 <pr-url>` in the foreground, run again on exit 124.

Never watch CI any other way: no `gh pr checks --watch`, no `sleep` loops, no re-running `pr.py status` to see how far it got. Each of those spends tokens on progress the status line already shows.

Act on its exit code:

- **0 green** → stage 6.
- **1 red** → it prints each failed check and the part of its log that leads to the error. Fix the cause here, run the gate, commit, push, and wait again. When the failure is unrelated to the change (it also fails on the base branch, or the CI environment broke), do not work around it and do not stop silently: rerun it once with `gh run rerun <run-id> --failed` when it looks flaky, otherwise show the user the failure and ask, following the `questions` skill, whether to fix it in this PR.
- **2 unpushed** → push, and wait again.
- **3 conflict** → merge the base branch into the goal's branch, resolve the conflicts here, run the gate, push, and wait again. Merge rather than rebase, so pushing never needs `--force`.

### 6. Final validation — always, on a green PR

Only after stage 5 exits 0 for the latest commit. Brief: prove the change works by running it, not by reading it. On the goal's branch, run every acceptance criterion in the requirement as an observable check, plus the project's formatter, linters, type checks, tests and builds. Record each command and the part of its output that proves the result. Anything that cannot be run here (needs hardware, a reboot, a deploy, a credential) is reported as NOT RUN with the reason; it is never assumed to pass.

On FAIL: fix the problems here, run the gate, commit, push, wait for stage 5 again, then run the check again. NOT RUN items do not block the PR, but they are listed in it.

### 7. Verify — always, on a green PR

Run `/verify` in a fresh subagent as the `acceptance-tester` agent. It drives a browser and a terminal, which the `verifier` agent's tools do not allow. Brief: the goal, where the requirement and the decisions file live, the branch, the path to `/verify`'s skill file (`~/.agents/skills/verify/SKILL.md`), and every answer the user has given for this goal so far. It follows the skill in full and writes its report and screenshots under `.ship/<goal>/verify/`, not `verification/`.

The subagent cannot reach the user. When it needs something only the user can answer (how to run the app, credentials, what correct looks like), it stops and returns the questions instead of guessing. Ask them here, following the `questions` skill, save each answer as `/verify`'s Remembering section says, then dispatch a new verify subagent with the answers in its brief. Hand credentials over as environment variables in the brief, never in a file. Question rounds do not count as retries.

On FAIL: fix the problems here, run the gate, commit, push, wait for stage 5 again, run the final validation again (its PASS predates the fix), then run `/verify` again. NOT RUN tests do not block the PR, but they are listed in it.

## Retries

Each check, and CI, gets at most 2 fix-and-recheck rounds. Still failing after that → stop and show the user the latest report (for CI, the failures `pr.py` printed), then ask how to continue, following the `questions` skill. Never weaken a check, skip or disable a CI job, edit a report, or drop a requirement item to get a PASS.

## 8. Done — a mergeable PR

Update each PR's description (`gh pr edit --body`) so it also lists the checks that ran with their verdicts, and every NOT RUN item of the final validation. `/verify`'s results stay out of the description, which would go stale the next time `/verify` runs: once each PR exists, post its branch's final `/verify` report on it with `publish.py --pr <url>`, as `/verify`'s "Post it on the PR" step describes. That comment carries the tests, the screenshots and the NOT RUN tests, and replaces the comment of any earlier run. When `publish.py` reports the screenshots were not uploaded, it posts the comment without them and writes `<n>-report-standalone.html`; hand that file to the user, as `/verify`'s step 9 says.

Then mark each PR ready with `gh pr ready` and wait once more with `pr.py wait --final <pr-url>`, in the background as in stage 5: leaving draft can start more checks, and the base branch may have moved. Only exit 0 means done. Exit 1 or 3 sends the work back to stage 5, and the final validation and `/verify` run again after the fix. When `pr.py` says the PR still waits for a human review or another merge rule, the run is done; say so in the report.

Report to the user: what was built, that each PR is green and mergeable, the verdict of every check and how many rounds each took, review findings fixed vs skipped, what simplify changed, NOT RUN items, the `/verify` report path and its PR comment URL (and the standalone report's path when the screenshots were not uploaded), then the PRs as a list — one bullet per PR with its title and URL. Then open the final `/verify` report in the browser by running `~/.agents/skills/verify/scripts/report.py` on its `<n>-report.json`.

Finally, release the claim and remove the goal's worktree (see Claiming the task and Where the work happens). Never do either, or report the run as finished, before `pr.py wait --final` exits 0 for every PR.

## Never

- Never run unless the user explicitly invoked this skill.
- Never work on a task without holding its claim, or take one another live agent holds unless the user confirms it.
- Never build in `<main>`'s working tree; build in the goal's worktree.
- Never skip the final validation or `/verify`, with or without `--critical`.
- Never ask whether to stop after prototypes; the user's pick ships.
- Never dispatch a check or push while the gate is red.
- Never run the final validation or `/verify` on a PR whose CI is pending or red.
- Never watch CI by polling in this session; `pr.py wait` in the background does the waiting.
- Never call the run done while any check on the PR is pending or failing, or while it is a draft.
- Never let a checker fix what it checks, or see the conversation that produced the work.
- Never claim a check passed that did not run.
- Never edit or delete an earlier verification report.
