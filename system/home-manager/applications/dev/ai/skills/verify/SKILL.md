---
name: verify
description: Verify a finished change the way its end user would — in a real browser for web apps (Playwright MCP), in a real terminal for CLIs and TUIs, with curl against the running API for backend-only changes. Runs every test on the code before the change and after it, side by side, captures screenshots as proof, and writes a report with plain-language steps and a PASS/FAIL per test. Not the formatter/lint/unit-test validation /implement already does. Only use when the user explicitly runs the /verify command; never trigger on your own.
disable-model-invocation: true
---

# Verify

This skill is acceptance testing. `/implement` already proved the code is formatted, linted, type-checked and unit-tested. This skill answers a different question: **does the change work for the person who uses it?** It drives the real product the way that person would, once on the code before the change and once after it, and brings back screenshots as proof.

Four rules hold the whole skill up. Everything below is detail.

1. **Test as the end user, through the end user's interface.** A unit test, a code read, or an internal function call is never a substitute for using the product. If the end user clicks, you click; if they type a command, you type it.
2. **Before and after, side by side.** Every test runs on the base and on the change. An "after" on its own cannot show that the change is what made the difference.
3. **No proof, no PASS.** Every verdict carries a screenshot. A test you could not run is NOT RUN, never PASS.
4. **Ask only what you cannot find out; remember what you were told.** How to run the app, which credentials to use: ask when the code, the docs and your tools cannot tell you, and save the answer so the next session does not ask again.

## Who is the end user

Pick the interface from what the change touches, not from what is easiest to drive.

| Change touches                       | End user           | Drive it with                                                                                                  |
| ------------------------------------ | ------------------ | -------------------------------------------------------------------------------------------------------------- |
| A web UI (any frontend change)       | Person in browser  | Playwright MCP. Browser only.                                                                                  |
| A CLI command or TUI                 | Person in terminal | A real terminal through `scripts/term.sh`: type commands, press keys, read and screenshot the screen.          |
| A backend/API only, no UI change     | Frontend developer | `curl` (or `grpcurl`, `websocat`, …) typed in a `term.sh` terminal, against the running server.                |
| A library or SDK                     | Developer using it | A tiny consumer program that uses it the way its README says, run in a `term.sh` terminal.                     |
| Config / infra (e.g. a NixOS module) | Operator           | Apply it to a disposable target (VM, container) and use the resulting system the way an operator would.        |

A change spanning several rows gets tests in each: a new endpoint plus a new page is tested in the browser and with curl. For anything else (a desktop app, a mobile app), work out who uses it and drive what they drive; ask when you cannot.

A UI verdict comes from the rendered page in a browser. Never decide one with curl, a DOM query or the source. If Playwright MCP is missing or cannot start a browser, use another browser-driving tool the session has; with none, the UI tests are NOT RUN and you say why.

## Running the session

### 1. Load the goal

Resolve the `<goal>` the same way `/implement` does: the name or path the user gave, else the goal under `.goals/` the current branch name starts with, else the only goal with a plan. Several candidates → ask which, following the `questions` skill. Read the requirement and the plan: the requirement's acceptance criteria are what you test, the plan's Verification section is a hint at how.

No goal at all is fine; the user may run `/verify` on any branch. Then `<goal>` is the branch name in kebab-case, the change is the diff from the branch's base, and the tests come from the commits, the PR description, and what the user said.

### 2. Recall what you already know

Before working anything out, read your saved notes for this project (see Remembering). They may already say how to start the app, which port, which test account, which seed data. Use them; do not ask again.

### 3. Design the tests

Turn each acceptance criterion, or each user-visible effect of the diff, into one test: a short sequence of user actions and one observable check. Add a regression test for each area the change touched that a user would notice breaking (the neighbouring page, the old flag). Aim for the fewest tests that cover every criterion; this is not a full test pass of the product.

For each test, write down what **before** and **after** should show. Usually before shows the old behaviour (square avatar, 404, unknown flag). For a regression test, or a change with no visible effect (a refactor, a speed-up), both should look the same.

### 4. Set up before and after

Never disturb the user's checkout. Make two detached worktrees outside it, in a temp or scratch directory:

```sh
base=$(git merge-base <base-branch> HEAD)   # base branch: the PR's, else the repo's default branch
git worktree add --detach <tmp>/before "$base"
git worktree add --detach <tmp>/after  HEAD
```

`--detach` matters: the branch is usually checked out in the user's checkout already, and git refuses to check it out twice.

- **Uncommitted work.** If the user's checkout has uncommitted changes, they are part of the change: apply them to `after` (`git diff HEAD --binary | git -C <tmp>/after apply`, then copy untracked files) and say so in the report.
- **Local config.** A fresh worktree lacks gitignored files the app needs (`.env`, `*.local.*` config). Copy them from the user's checkout into both sides. They are deleted with the worktrees.
- **Both running at once.** Give each side its own port (`PORT=3001` / `PORT=3002`, `--port`), checking first that the port is free. Give each its own state: database file or schema, data dir, Docker Compose project name (`-p verify-before`), and for CLIs its own `HOME` / `XDG_*`. Never point either side at shared or production data.
- **Start and wait.** Install dependencies and build in each worktree. Run servers in the background and poll the health URL or port until ready; do not just sleep.
- **No base.** A brand-new project or file has no before. That side is "n/a, did not exist" in the report, and the test is judged on after alone.

If the app needs secrets, services, or seed data you cannot find in the repo, the docs, or your notes, ask (step 5). If something cannot run locally at all, the tests that need it are NOT RUN. Never test against production without the user's explicit go-ahead.

### 5. When you must ask

Ask only when the code, the docs, your notes and your tools cannot answer. That is typically:

- **How to run or reach it.** The start command is not discoverable, or the app needs a service you cannot start.
- **Credentials.** A login, an API token, a test account. Ask for test credentials, never a real user's.
- **What "correct" looks like.** The requirement does not say, and the before/after difference does not settle it.

Every question passes the `questions` skill first, one at a time. Save each answer that will still hold next time (see Remembering) before carrying on.

When `/ship` runs this skill in a subagent, you cannot reach the user. Stop instead, and return the questions with what each one blocks; `/ship` asks them, saves the answers, and starts you again with them.

Keep secrets out of the proof. Pass a token as an environment variable (`term.sh start <goal>-after <dir> TOKEN=...`) and type `$TOKEN`, so the screenshot shows the name, not the value. Never write a secret into the report, your notes, or a commit; refer to it by name ("the staging admin account").

### 6. Run each test, on both sides

Run the steps on **before**, then the same steps on **after**. Save screenshots under `.goals/<goal>/verify/<n>/`, where `<n>` is one higher than the highest existing report number: `<test>-before.png` and `<test>-after.png`, plus `<test>-before-<step>.png` for any extra step a reader needs to follow along. Look at every screenshot you take. A PNG is the proof; a text dump next to it is welcome but no substitute.

**Web.** Drive the browser with Playwright MCP.

- Run the sides one after the other and close the browser (`browser_close`) between them. Both sides are on `localhost`, and cookies ignore the port, so a session left over from one side would leak into the other.
- Use the same viewport size on both sides (`browser_resize`), so the screenshots compare.
- Find elements with `browser_snapshot`; judge what the user sees from the screenshot.
- Save screenshots with `browser_take_screenshot`, giving `filename` as an **absolute** path into the report directory; a relative name lands in the server's own output directory. Capture the viewport at the moment of the check. When the change is small (an icon, a border), add an element screenshot of it next to the viewport one. Use a full-page shot only when the change is below the fold.

**CLI, TUI, API.** Drive a real terminal with `scripts/term.sh`, in this skill's directory (`~/.agents/skills/verify/` or `~/.claude/skills/verify/`). It runs a clean bash with a `$ ` prompt on a private tmux server, so the user's own tmux is untouched, and renders the screen to PNG with `freeze`. Other runs may share that server, so prefix session names with the goal.

```sh
T=~/.agents/skills/verify/scripts/term.sh
$T start <goal>-before <tmp>/before HOME=<tmp>/home-before  # clean shell in a dir, extra env optional
$T type  <goal>-before 'todo add milk'                      # type a command, press Enter
$T wait  <goal>-before                                      # until the screen stops changing
$T read  <goal>-before                                      # the screen as text, for you to judge
$T shot  <goal>-before .goals/<goal>/verify/<n>/1-before.png
$T keys  <goal>-before Down Down Enter                      # drive a TUI: Up, Tab, Escape, C-c, q ...
$T until <goal>-before 'Listening on' 60                    # wait for text to appear
$T clear <goal>-before                                      # clean screen before the next test
$T stop  <goal>-before <goal>-after
```

- **CLI / TUI.** Type the command exactly as a user would, with the user-facing binary or script, never an internal entry point. `wait` (or `until`) before every `read` and `shot`.
- **API.** Type the request into a `term.sh` terminal so the screenshot shows the command and the response together: `curl -sS -i` for the status line, headers and body, or pipe a JSON body through `jq`. `clear` before each request so one screenshot holds one exchange.

**Verdicts.** Judge each test on what you saw, and give it one verdict:

- **PASS.** After shows the expected behaviour, and before shows what you expected of it.
- **FAIL.** After does not behave as expected, or, for a test of the change, before already behaves like after, so the change made no visible difference. Record what happened instead.
- **NOT RUN.** Blocked: no credentials, an unreachable service, an environment that cannot host it. Record why.

Do not fix failures. This skill reports.

### 7. Clean up

Stop every server and `term.sh` session you started, close the browser, and remove both worktrees (`git worktree remove --force`). Leave the screenshots and the report.

### 8. Write the report

Write `.goals/<goal>/verify/<n>-report.md`. Each run gets its own number; earlier reports are never edited. `.goals/` is local working state, never committed: create `.goals/.gitignore` containing `*` if it is missing.

```markdown
# Verification <n> — <goal>

- **Date:** <date>
- **Before:** `<base ref>` (<short sha>) at <URL or dir> · **After:** `<branch>` (<short sha>) at <URL or dir>
- **Result:** <x> PASS · <y> FAIL · <z> NOT RUN

| #   | Test                      | Verdict    |
| --- | ------------------------- | ---------- |
| 1   | Profile image is a circle | ✅ PASS    |
| 2   | Settings page still loads | ❌ FAIL    |
| 3   | Admin can reset the image | ⏸️ NOT RUN |

## 1. Profile image is a circle — ✅ PASS

**Steps**

1. Open the browser
2. Go to the application
3. Click the user profile in the top right corner
4. Click Settings
5. Check that the profile image is a circle (it used to be a square)

| Before                       | After                        |
| ---------------------------- | ---------------------------- |
| ![before](<n>/1-before.png)  | ![after](<n>/1-after.png)    |
| Square image, as expected.   | Circle image, as expected.   |

## 2. ...

## Setup

- **Before:** <how it was started: command, port, state dir>
- **After:** <same>
- <uncommitted changes applied, copied local config, anything else a reader needs to reproduce it>
```

Steps are plain user actions, one per line, with no implementation detail: "Click Settings", "Run `todo add milk`", "Send `GET /users/42` with the admin token". The last step is the check, with the old behaviour in parentheses when it changed. A FAIL says under its images what happened instead; a NOT RUN says what blocked it.

### 9. Finish

Report in chat: the result line, the table of tests with verdicts, the path to the report, and one line per FAIL or NOT RUN saying what went wrong or what blocked it.

When `/ship` is driving this skill, stop after the chat report; `/ship` opens the PR.

Otherwise `/verify` is the last step of the workflow. When everything passed, tell the user the change is verified and the workflow is complete. Otherwise, name what failed or was not run; fixing it is a new piece of work, not part of this skill.

## Remembering

Whenever the user tells you something you could not work out yourself (how to start the app, which port or URL, which test account, how to seed data, what a page is called, that a flow needs a feature flag), save it so the next `/verify` on this project starts with it. Save it as soon as you have the answer, not at the end.

- Use the agent's native persistent memory when it has one (Claude Code's memory directory, for example): one fact per entry, naming the project.
- Otherwise append to `~/.agents/verify-notes/<project>.md`, where `<project>` is the repo's directory name.
- Save the fact and how to use it, never a secret's value. "Admin test login: ask the user; it is `myapp-staging-admin` in their password manager" is fine; the password is not.
- When a saved note turns out to be wrong, fix or delete it.

## Never

- Never run unless the user explicitly invoked this skill or `/ship`.
- Never ask a question outside the `questions` skill.
- Never decide a verdict from code, unit tests, or internal calls instead of the end user's interface.
- Never mark PASS without a screenshot you looked at, or claim a test ran that did not.
- Never test only the after side.
- Never touch the user's checkout, shared data, or production without explicit permission.
- Never write a secret into the report, your notes, a screenshot, or a commit.
- Never fix the code; report and stop.
