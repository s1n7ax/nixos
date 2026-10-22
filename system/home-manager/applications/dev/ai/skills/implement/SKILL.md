---
name: implement
description: Build the requirement documented by /requirement. Starts by analyzing the code — asking for access first when the code is out of reach — and proves unverified claims with throwaway spikes. Before writing any code, asks the user only about approach forks, significant stretches, and requirement gaps, one question at a time. Then implements, runs /code-review in a subagent, tracks findings in the goal's code-review directory, fixes them in the same session, and runs /simplify in a subagent. Only use when the user explicitly runs the /implement command; never trigger on your own.
disable-model-invocation: true
---

# Implement

This skill is execution. The user arrives with a confirmed requirement — usually written by the `/requirement` skill — and this skill works out how to build it, settles the decisions that need the user, builds it, reviews it, fixes the review findings, and simplifies the result, all in one session.

Four rules hold the whole skill up. Everything below is detail.

1. **The requirement is the contract.** It is the definition of done. Never expand scope beyond it, however tempting the nearby work.
2. **Decide before you build.** Analyze the code and settle every decision that needs the user before writing a line of it. Code written before a fork is settled may be thrown away.
3. **Code first, questions last.** Ask only the three allowed question types, and only when the code, the docs, a spike, and your tools cannot settle it. Every question passes the `questions` skill, one per turn.
4. **Everything is written down.** Decisions go in the goal's decisions file, review findings and their fixes in its `code-review/` directory. Both are updated, never rewritten.

## Running the session

### 1. Load the goal

Resolve the `<goal>`:

- The user gave a goal name or path → use it.
- The current branch name starts with a goal directory name under `.goals/` → use that goal.
- Exactly one goal under `.goals/` has a requirement → use it.
- Several candidates → ask which one, following the `questions` skill, and wait.
- None → tell the user to run `/requirement` first, and stop.

Read the requirement — `.goals/<goal>/requirement/requirement.md`, or the ticket when `/requirement` wrote it to a project ticket — and the decisions file if one exists (`.goals/<goal>/decisions/decisions.md`, or the ticket). A decision already recorded is settled; never ask it again. For a ticket, `<goal>` is a short kebab-case description of what the requirement achieves (e.g. `validate-requests`).

### 2. Analyze

Read every project the requirement touches and work out the viable ways to build it, and the decisions each one forces, before asking anything. The first question must already be informed.

#### When the code is out of reach

If a project the requirement touches is not readable, getting access comes first — before any other question.

1. **Use what already works.** A local checkout, a connected MCP for the code host, or an authenticated CLI such as `gh` that can read the repo. If one works, read the code and carry on — no question.
2. **Otherwise, ask for access.** Suggestions, ranked: clone the project (recommended — full, fast local reads), set up a CLI such as `gh`, or add an MCP for the code host.
3. **Never build blind.** Do not guess the code, and do not replace reading it with questions. If access cannot be had, say which project is blocked and stop.

#### When the code cannot prove it

The build hinges on a technical claim the code and docs cannot prove ("the library's webhook retries at least once"). Do not guess and do not ask — prove it yourself.

1. **Read deeper first.** The library's source, its tests, its issue tracker.
2. **Still unproven → spike it.** Make the smallest change that proves or disproves the claim — in a new throwaway project outside every repo, or on a `<goal>_spike_<claim>` branch (`<claim>` a short kebab-case name for the claim) in a separate git worktree of an existing project, so the user's checkout, its current branch, and its uncommitted changes stay untouched. A spike is evidence, not implementation: never pushed, never a PR, never merged. Keep it local — no shared or production systems, real secrets, or paid resources; if proving the claim needs one, ask permission first.
3. **Build on facts.** Record the finding, and where the spike lives, in the decisions file. A disproven claim usually surfaces a new Type 1 or Type 2 question — ask it.

Spike only claims that decide whether an approach is viable; claims that matter only inside one approach wait until it is chosen.

### 3. Decide

Ask breadth-first: the big forks and stretches in dependency order before any detail. After each answer, note briefly what is now decided and what is ruled out, and write it to the decisions file. Stop asking when every remaining decision passes the gate test below as yours.

#### Type 1 — Fork in the road

Two or more clearly viable approaches exist, and every one of them satisfies the requirement. Ask which one the user prefers. If the user keeps more than one, record each as an approach (see Multiple approaches) and move on.

> **Where should request validation live?**
>
> All three spots satisfy the requirement; they differ in how much code moves and who owns the rule.
>
> 1. **In the existing shared schema package — recommended.** One definition, both projects import it. Simplest change, and the rule cannot drift between projects. Cost: a version bump of the shared package.
> 2. **In each project separately.** No cross-project dependency, but the rule now exists twice and will drift.
> 3. **In a new validation service.** Cleanest separation and scales to future projects, but a new deployable to run and monitor — the most moving parts by far.

#### Type 2 — Significant stretch

The change costs something big or risky. **Always ask**, even when only one way exists — the real question is "is this stretch acceptable?" The triggers:

- The existing architecture cannot deliver the requirement: a breaking change, a new dependency, a new service or project, a schema migration, removing existing behavior.
- The security or permission surface grows: new secrets, broader permissions, a new exposed endpoint, handling sensitive data for the first time.
- The change crosses an ownership boundary: it touches a project owned by someone else or shared with other efforts.

The user may opt out. When they do, move the unachievable part of the requirement into **Out of scope** with the reason (e.g. "full-text search — rejected, new dependency was too big a stretch"), then build around what remains.

> **The search requirement needs a real index, and the current in-memory store cannot provide one. The only viable path adds a new dependency (a search engine) and a new service in docker-compose. Is that stretch acceptable?**
>
> 1. **Yes, add it — recommended.** The requirement explicitly demands typo-tolerant search; no in-process trick delivers that.
> 2. **No — cut search back to exact filtering on existing fields.** "Typo-tolerant search" moves to out of scope, with the reason: new dependency rejected.

#### Type 3 — Requirement gap

The requirement is silent on something that forks the build — a decision no code exploration can settle. Ask it, framed as the consequence the user feels, then write the answer into the requirement — under **Requirements** or **Constraints**, in the user's words.

If the gap unravels the requirement itself rather than a corner of it, do not patch it one question at a time: name the gap, tell the user it needs another `/requirement` pass, and stop until it is resolved.

#### Everything else is yours to decide

> Could a strong engineer, given this requirement and this codebase, decide this without the user's taste or risk appetite?

Yes → decide it yourself, without asking. No → it must fit one of the three types to be asked. If it fits none, decide it yourself. Record the decisions a reviewer would otherwise question.

#### When `/ship` runs this step in a subagent

You cannot reach the user. Never guess an answer that belongs to them, and never write code with a question open. Stop and reply with every question you have at this point, each already shaped by the `questions` skill — the question, its options with the recommendation first, and what it blocks — plus what you found that `/ship` needs to ask it well. `/ship` asks them and resumes you with the answers; carry on from there.

#### The decisions file

The decisions file lives next to the requirement: `.goals/<goal>/decisions/decisions.md` for a local requirement, added to the ticket for a ticket. `.goals/` is local working state, never committed: before writing anything under it, create `.goals/.gitignore` containing `*` if it is missing, so git ignores the directory in every checkout.

```markdown
# Decisions — <goal>

Implements: <path or link to the requirement>

- **<decision>** — <why>. Decided by: user | agent. Rejected: <alternatives> (<why rejected>).

## Spikes

- **<claim>** — proven | disproven. <what showed it>. Lives at: <path or branch>.

## Approaches

Only when the user kept several options; drop the section otherwise.

### <approach> — branch `<goal>_approach_<approach>`

<what sets this approach apart, in one line>
```

#### Multiple approaches

When the user keeps more than one option at a fork, build each kept option as a full approach.

1. **Production-ready, never throwaway.** Build every approach to the same standard — any of them may be the one that ships.
2. **An approach spans every project.** If option 1 in project `api` forces a matching change in `web`, approach 1 covers both: its `api` and `web` changes ship or drop together.
3. **At most 3 approaches in total.** When more than one fork is kept open, each approach is one end-to-end combination of the kept options. If the combinations would exceed 3, ask which ones to keep.
4. **One branch name per approach.** `<goal>_approach_<approach>`, with `<approach>` a short kebab-case name for the approach. The repo already says which project it is, so the same name in every repo ties one approach's PRs together: the shared-schema approach for `validate-requests` across `api` and `web` → branch `validate-requests_approach_shared-schema` in both.
5. **The user picks after the PRs exist.** One PR per project per approach. The user reviews them and picks one approach; its PRs get merged, the others closed.

### 4. Set up the workspace

Work on a `<goal>` branch created from the project's base branch, or with approaches one `<goal>_approach_<approach>` branch per approach. Never commit to the user's current branch unless it is already the goal's branch.

### 5. Implement

Build the requirement the way the decisions file says, across every project it touches. When a change in one project depends on a change in another, build them in that order. Commit per logical change. Stage files by path.

When the code surprises you mid-build with a decision that fits one of the three question types, stop that line of work and ask it — through `/ship` when it drives, as Decide says. Commits already made stay; do not roll them back unless the user asks. Anything else you decide yourself and record.

### 6. Validate

Before review, prove the implementation works:

- Prove every acceptance criterion in the requirement with an observable check — a command, a test, an output you can show.
- Run the project's formatter, linters, type checks, tests and builds — the same commands CI and the pre-commit hooks run. Find them in the CI config, pre-commit config, task runner (`Makefile`, `justfile`, `package.json` scripts, flake `checks`/`formatter`) and contributing docs; never guess a subset.
- Run the formatter in its check mode (`--check`, `--fail-on-change`) after applying it, and commit what it changed. The working tree must be clean when Validate ends.

Fix failures and rerun until green. Never move to review with failing checks, and never claim a check passed that was not run. Report each command with its exit code.

### 7. Review

Run the review as a **subagent**: a fresh context does not defend the code it wrote. Where the environment provides named subagents (pi's `subagent` tool, Claude Code's Agent tool), dispatch the `code-reviewer` agent with the changes as the target, defaulting to `medium` effort unless the user asked for another level. The subagent reviews; it never fixes. If the environment has no subagent capability, run the review in this session and say so, per the code-review skill's own fallback rule.

Write the findings to `.goals/<goal>/code-review/<n>-review.md`, where `<n>` is one higher than the highest existing review number (`1-review.md` for the first). Each review round gets its own file; earlier files are never edited by later rounds.

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

### 8. Fix

Fix every finding in this same session, most severe first. For each one, apply the fix and update its entry in the review file — never in a separate document:

- **Fixed:** what changed and where (`- **Fix:** Fixed — <what changed, file/symbol>`).
- **Skipped:** only with a reason — the finding is false, the fix would change required behavior, or a recorded decision forbids it (`- **Fix:** Skipped — <reason>`).

After all fixes, rerun the Validation step. A fix that breaks a check is not a fix.

### 9. Simplify

Run `/simplify` as a **subagent**, for the same reason as the review. Simplify edits files, so dispatch an agent that can write — the `worker` agent where the environment names one (pi's `subagent` tool), otherwise a general-purpose agent (Claude Code's Agent tool) — telling it to read `~/.agents/skills/simplify/SKILL.md` and follow it on this goal's changes, naming the goal so it finds the requirement and decisions. If the environment has no subagent capability, run it in this session and say so.

Review the subagent's changes, then rerun Validation. Simplify is quality-only; its changes need no entries in the review file.

When `/ship` is driving this skill, stop here: `/ship` runs its own checks and opens the PRs.

### 10. Finish

- With approaches: one PR per project per approach, on the approach's branch, so the user can pick.
- Otherwise: one PR per project, unless the project says otherwise.
- Report: what was built, the decisions the user made, review findings fixed vs skipped, what simplify changed, validation results, then the PRs as a list — one bullet per PR with the PR title and URL, grouped by project (and by approach when there are approaches).

## Handing off to the next step

When `/ship` is driving this skill, skip this section.

After finishing, the workflow's next step is `/verify <goal>`, which tests the change the way its end user would. If review or validation left unresolved work, name it explicitly instead, and do not hand off.

1. **Tell the user** the next step: run `/verify <goal>`.
2. **Copy the command to the clipboard** so the user can paste it: run `printf '%s' '/verify <goal>' | wl-copy` (Wayland; fall back to `xclip -selection clipboard` or `xsel --clipboard` when wl-copy is unavailable).
3. **Confirm the copy worked** — say the command is on the clipboard.

## Never

- Never run unless the user explicitly invoked this skill or `/ship`.
- Never start without the requirement.
- Never ask a question before analyzing the code.
- Never ask a question outside the three allowed types, except the ones that keep the session moving: code access, spike permission, which goal, which approaches to keep.
- Never break a `questions` skill rule — the dumbness score, one question per turn, the option cap, the ask-question tool.
- Never write code while a question that belongs to the user is open, or guess its answer.
- Never ask again what the decisions file already records.
- Never build more than 3 approaches.
- Never skip the review, the fix pass, or the simplify pass.
- Never mark a finding fixed without the fix applied and validation rerun.
- Never edit or delete an earlier review file.
- Never claim tests, checks, or reviews ran that did not run.
- Never expand scope beyond the requirement, however tempting the nearby work.
