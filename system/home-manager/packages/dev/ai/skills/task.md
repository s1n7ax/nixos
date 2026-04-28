---
name: task
description: Use whenever the user invokes `/task`, says "let's work on <something>", pastes a project-management ticket URL (GitHub issue, Jira, Linear, etc.) as the work to do, or otherwise asks to start a new piece of coding work end-to-end. Drives a coding task through a fixed pipeline — understand the requirement, plan, ticket, branch, implement, test via end-user API, commit, PR, link — pausing for user input at every checkpoint. Use this even when the user does not say the word "task"; if they are framing the next chunk of work, this skill applies.
---

# Task workflow

Drive a coding task through nine stages. Do not skip stages silently. If a stage is genuinely unnecessary for this task (e.g. a one-line typo fix), say so and ask the user to confirm before skipping.

The "X" the user gave you may be a description, a ticket URL, or a vague phrase. Treat all three the same — start at stage 1.

You are pairing with a senior engineer. Be terse, ask sharp questions, do not lecture.

## Stage 1 — Understand the requirement

The single most important rule: understand the **end-user requirement**, not the list of code changes the user or ticket happens to mention. Tickets and users routinely describe a proposed solution; recover the underlying problem so you can challenge the proposed solution if a better one exists.

If the input is a ticket URL, fetch the details in this order:

1. A relevant MCP (e.g. `mcp__github__*`, `mcp__atlassian__*`, `mcp__linear__*`)
2. A supported CLI (`gh issue view`, `jira issue view`, `linear`, etc.)
3. `WebFetch` on the URL as a last resort

Read the ticket body, comments, and linked context. Then put it aside and re-derive the requirement in your own words.

If the input is a description, restate it back as a requirement, not a task list. Example:

- User: "Add a `force` flag to the deploy command." → Bad: "OK, I'll add `--force`." Good: "What problem does `--force` solve? Are users hitting a confirmation that's wrong, or do they need to bypass a safety check? If the latter, why is the check firing when it shouldn't?"

Always ask clarifying questions before moving on. Even if it feels clear, ask at least one probing question about the _why_. Never proceed past this stage on assumptions.

When you think you have it, write a one-paragraph summary of the requirement and ask the user to confirm. Only then continue.

## Stage 2 — Explore the code and plan

Read the relevant code first. Do not propose a plan based on guesses about the codebase.

Produce **multiple candidate solutions**, sorted **most-recommended first**. For each: a one-line description, the rough shape of the change, and the main tradeoff. Even when one solution is obviously right, include at least one alternative — it forces you to articulate why your preferred approach won.

Present the options. Iterate: refine, drop, merge, ask questions. Continue until the chosen plan is crystal clear — concrete files, functions, behaviour. If any part is fuzzy, surface that instead of papering over it.

## Stage 3 — Ticket

If the work already has a ticket, skip this stage.

Otherwise create one. To pick the project-management tool, check in order:

1. Per-project memory: `~/.claude/projects/<project-slug>/memory/project-management.md`
2. Ask the user, then write the answer to the per-project memory file above so future invocations remember.

The memory file should be tiny — tool name and identifiers (Jira project key, Linear team, GitHub repo). Example:

```
Tool: GitHub Issues
Repo: s1n7ax/nixos
```

Create the ticket via MCP > CLI > web (same fallback as stage 1). Capture the ticket ID and URL.

## Stage 4 — Branch

Branch from the **latest** default branch:

```
git fetch origin
git checkout <default-branch>
git pull --ff-only
git checkout -b <ticket-id>-<short-kebab-description>
```

Branch name: `<ticket-id>-<short-kebab-description>` (e.g. `PROJ-123-add-force-flag`, `gh-42-fix-login-redirect`).

Before creating the branch, check the current branch:

- If its name suggests it was created for _this_ ticket (matches the ticket ID, or clearly describes the same work), ask the user whether to continue on it or branch fresh.
- Otherwise create a new branch without asking.

If the working tree is dirty, stop and ask — do not stash or discard silently.

## Stage 5 — Implement

Make the changes per the plan. Read before editing, keep changes scoped to the plan.

If you discover the plan is wrong mid-implementation, stop and renegotiate — do not improvise a different plan silently.

## Stage 6 — Test via the end-user API

Theme: exercise the change the way the end user would, not via internal helpers.

- HTTP backend: start the app, send real HTTP requests (`curl`, `httpie`, etc.) against the endpoint
- Frontend: drive the UI via the or `claude-in-chrome` MCP or `playwright-mcp`
- CLI tool: run the built binary with real arguments
- Library: call the public exported API from a small script
- Infra/config: apply the config to a real (or local) target and verify the observable effect

Also run the project's existing test suite

If anything fails: fix, retest, repeat. Do not move on with failing tests.

## Stage 7 — Commit

Use the **`git-commits`** skill. Do not hand-roll commit messages.

## Stage 8 — Pull request

Use the **`pull-request`** skill. Do not hand-roll the PR body.

## Stage 9 — Link the PR to the ticket

Connect the PR to the ticket so both sides reflect the relationship:

- GitHub Issues: include `Closes #<n>` / `Fixes #<n>` in the PR body. Verify it was added.
- Jira: include the issue key in the PR title or branch name (Jira's GitHub integration auto-links). If the org uses Smart Commits, also add `<KEY> #comment Linked PR <url>`.
- Linear: add `Closes <TEAM-123>` (or the magic word configured by the workspace).
- Other: post a comment on the ticket with the PR URL, and a comment on the PR with the ticket URL.

Confirm the link is visible from both sides before declaring the task done.

## Checkpoints

After each of stages 1, 2, 3, 4, 6, 8, pause and confirm with the user before continuing. The point of this skill is that the human stays in the loop at every meaningful decision boundary.
