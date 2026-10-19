---
name: verify
description: Verify a finished implementation the way its end user would — in a real browser for web apps (Playwright MCP), in a real terminal for CLIs and TUIs, with curl against the running API for backend-only changes. Runs every test on both the base (before) and the change (after) side by side, captures screenshots as proof, and writes a report with plain-language steps and a PASS/FAIL per test. Not the formatter/lint/unit-test validation /implement already does. Only use when the user explicitly runs the /verify command; never trigger on your own.
disable-model-invocation: true
---

# Verify

This skill is acceptance testing. `/implement` already proved the code is formatted, linted, type-checked and unit-tested. This skill answers a different question: **does the change actually work for the person who uses it?** It drives the real product the way that person would, on the code before the change and after it, and brings back screenshots as proof.

Four rules hold the whole skill up. Everything below is detail.

1. **Test as the end user, through the end user's interface.** Never substitute a unit test, a code read, or an internal function call for using the product. If the end user clicks, you click; if they type a command, you type it.
2. **Before and after, side by side.** Every test runs on the base and on the change. A test that only shows the "after" proves nothing changed because of the work.
3. **No proof, no PASS.** Every verdict carries a screenshot. A test you could not run is NOT RUN, never PASS.
4. **Ask only what you cannot find out; remember what you were told.** How to run the app, which credentials to use — ask when the code and tools cannot tell you, and save the answer so the next session never asks again.

## Who is the end user

Pick the interface from what the change touches, not from what is easiest to drive.

| Change touches                         | End user           | Drive it with                                                                                       |
| -------------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------- |
| A web UI (any frontend change)         | Person in browser  | Playwright MCP (`browser_navigate`, `browser_click`, `browser_take_screenshot`, …). Browser only.   |
| A CLI command or TUI                   | Person in terminal | A real terminal session in `tmux`: `send-keys` to type, `capture-pane -e -p` to read the screen.    |
| A backend/API only, no UI change       | Frontend developer | `curl` (or `grpcurl`, `websocat`, …) from a terminal, against the running server.                    |
| A library or SDK                       | Developer using it | A tiny consumer program that imports it the way the README says, run from a terminal.               |
| Config / infra (e.g. a NixOS module)   | Operator           | Apply it in a disposable target (VM, container) and use the resulting system the way an operator would. |

A change spanning several rows gets tests in each — a feature with a new endpoint and a new page is tested in the browser *and* with curl. For a web change, never fall back to curl or DOM queries to decide a UI verdict; read the rendered page and screenshot it.

## Running the session

### 1. Load the goal

Resolve the `<goal>` the same way `/implement` does: the name or path the user gave, else the current branch's goal under `.goals/`, else the only goal with a plan. Several candidates → ask which, following the `questions` skill. Read the requirement and the plan; the requirement's acceptance criteria are what you test, the plan's Verification section is a hint at how.

No `.goals/` at all is fine — the user may run `/verify` on any branch. Then the change is the diff between the branch and its base, and the tests come from the commits, the PR description, and what the user said.

### 2. Recall what you already know

Before working anything out, read the saved verification notes for this project (see Remembering). They may already say how to start the app, which port, which test account, which seed data. Use them; do not re-ask.

### 3. Design the tests

Turn each acceptance criterion — or each user-visible effect of the diff — into one test: a short sequence of user actions and one observable expectation. Add a test for anything the change could plausibly break that a user would notice (the neighbouring page, the old flag still working). Write the steps the way you would explain them to a non-technical colleague.

For each test, write down what the **before** side is expected to show. Usually it shows the old behaviour (square avatar, 404, missing flag). If before and after are expected to look the same — a pure refactor, a performance fix — say so; the test then proves nothing regressed.

### 4. Set up before and after

Never disturb the user's checkout. Create two worktrees outside it:

```sh
git worktree add ../<repo>-verify-before <base>    # merge-base of the branch and its base branch
git worktree add ../<repo>-verify-after  <branch>
```

Build and start each one in isolation, so both run at the same time:

- Different ports (`PORT=3001` / `PORT=3002`, `--port`, a config override). Check a port is free before taking it.
- Separate state: its own database file or schema, its own data dir, its own `HOME`/`XDG_*` for CLIs that write config. Never point either side at shared or production data.
- Run long-lived servers in the background and wait for readiness (poll the health URL or the port) rather than sleeping.

If the app needs secrets, services, or seed data you cannot find in the repo, the docs, or the notes, ask (step 5). If something cannot run locally at all, say which test is blocked and mark it NOT RUN — never test against production without the user's explicit go-ahead.

### 5. When you must ask

Ask only when the code, the docs, the notes and your tools cannot answer — typically:

- **How to run or reach it**: the start command is not discoverable, or the app depends on a service you cannot start.
- **Credentials**: a login, an API token, a test account. Ask for test credentials, never for a real user's. Never write secrets into the report, the notes, or a commit; refer to them by name ("the staging admin account").
- **What "correct" looks like**: the requirement does not say, and the before/after difference does not settle it.

Every question passes the `questions` skill first, one at a time. Save each answer that will hold next time (see Remembering) before carrying on.

### 6. Run each test, on both sides

For each test, run the steps on **before**, then on **after**, the same way each time:

- **Web**: Playwright MCP against each side's URL. Take a `browser_take_screenshot` at the moment the expectation is checked (and at any step a reader would need to follow along). Prefer the accessibility snapshot to find elements; use the screenshot to judge what the user sees.
- **CLI / TUI**: a fresh `tmux` session per side (`tmux new-session -d -s verify-before -x 120 -y 35`), commands typed with `send-keys`, the screen read with `capture-pane`. Wait for output to settle before reading. Render the pane to an image for the screenshot — `freeze` (`tmux capture-pane -e -p | freeze -o shot.png`) when available, otherwise convert the ANSI capture to HTML (`aha`, `ansi2html`) and screenshot it with Playwright.
- **API**: type the `curl -i` command in a `tmux` pane so the screenshot shows both the command and the full response (status line, headers, body), then render the pane as above.

Save screenshots as `.goals/<goal>/verify/<n>/<test>-before.png` and `<test>-after.png` (or under `.verify/<n>/` without a goal), where `<n>` is the next unused report number. A PNG is the proof; a text dump alongside it is welcome but not a substitute.

Judge each side against its expectation and give the test one verdict, for the **after** side:

- **PASS** — after shows the expected behaviour, and before shows the expected old behaviour (or the same, for no-regression tests).
- **FAIL** — after does not behave as expected. Record what it did instead.
- **NOT RUN** — blocked (no credentials, unreachable service, environment cannot host it). Record why.

If **before already behaves like after**, the test is not proving the change: note it, and say whether the test is wrong or the change is a no-op.

Do not fix failures. This skill reports; fixing is `/implement`'s job.

### 7. Clean up

Stop every server and `tmux` session you started, and remove both worktrees (`git worktree remove`). Leave the screenshots and the report.

### 8. Write the report

Write `.goals/<goal>/verify/<n>-report.md` (or `.verify/<n>-report.md`). Earlier reports are never edited. `.goals/` is local working state: create `.goals/.gitignore` containing `*` if it is missing.

```markdown
# Verification <n> — <goal>

- **Date:** <date>
- **Before:** `<base ref>` (<short sha>) · **After:** `<branch>` (<short sha>)
- **Result:** <x> PASS · <y> FAIL · <z> NOT RUN

| #   | Test                       | Verdict |
| --- | -------------------------- | ------- |
| 1   | Profile image is a circle  | ✅ PASS |
| 2   | Settings page still loads  | ❌ FAIL |

## 1. Profile image is a circle — ✅ PASS

**Steps**

1. Open browser
2. Go to the application
3. Click on the user profile in the top right corner
4. Click Settings
5. Check that the profile image is a circle (it used to be a square)

| Before                          | After                          |
| ------------------------------- | ------------------------------ |
| ![before](<n>/1-before.png)     | ![after](<n>/1-after.png)      |
| Square image, as expected.      | Circle image, as expected.     |

## 2. ...
```

Steps are plain user actions — "Click Settings", "Run `todo add milk`", "Send `GET /users/42`" — one per line, no implementation detail. The last step is always the check, with what it used to be in parentheses when it changed.

### 9. Finish

Report in chat: the result line, the table of tests with verdicts, the path to the report, and for each FAIL or NOT RUN one line saying what went wrong or what blocked it. If anything failed, say that `/implement` (or a fix) is the next step; otherwise say the change is verified.

## Remembering

Whenever the user tells you something you could not work out yourself — how to start the app, which port or URL, which test account, how to seed data, what a page is called, that a flow needs a feature flag — save it so the next `/verify` on this project starts with it.

- Use the agent's native persistent memory when it has one (Claude Code's memory directory, for example), one fact per entry, naming the project.
- Otherwise append to `~/.agents/verify-notes/<project>.md`, where `<project>` is the repo's directory name.
- Save the fact and how to use it, never a secret's value. "Admin test login: ask the user; it lives in their password manager as `myapp-staging-admin`" is fine; the password is not.
- When a saved note turns out to be wrong, fix or delete it.

## Never

- Never run unless the user explicitly invoked this skill.
- Never ask a question outside the `questions` skill.
- Never decide a verdict from code, unit tests, or internal calls instead of the end user's interface.
- Never mark PASS without a screenshot, or claim a test ran that did not.
- Never test only the after side.
- Never touch the user's checkout, shared data, or production without explicit permission.
- Never write a secret into the report, the notes, or a commit.
- Never fix the code — report and stop.
