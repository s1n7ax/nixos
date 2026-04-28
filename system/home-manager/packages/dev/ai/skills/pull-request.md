---
name: pull-request
description: Use whenever the user asks to create, open, push, or submit a PR / pull request. Covers branch strategy, PR title/description conventions, and triaging Copilot review-bot comments.
---

# GitHub Pull Requests

## Steps

- Never commit directly to the default branch; create a dedicated branch per PR
- Commit the changes on the PR branch
- Push the branch
- Open the PR from that branch

## PR Title

Use conventional-commit syntax (same convention as git commits):

`<type>[scope]: <description>`

## PR Description

Summarize the changes in 1–3 bullet points.

## Review Bot Comments

Projects may have Copilot or similar review bots enabled. These bots mix valid findings with low-signal nits, so filter before surfacing anything to the user.

After creating the PR:

1. Check for review comments with `gh pr view --json reviews`
2. If none yet, tell the user the bot may still be processing and they can ask you to recheck later
3. When comments exist:
   - Read each one carefully
   - Challenge every suggestion — decide whether it is correct and applicable before presenting it
   - Discard false positives and pure stylistic nits with no real impact
   - Present only valid comments as a numbered list with file, line, and the suggestion
   - Ask the user which ones to fix
