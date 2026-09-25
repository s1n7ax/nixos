# Tracker mechanics

Where the map physically lives, and the exact commands to read and write it.
Read this when creating a map, resuming one, or finishing a step.

## Which tracker

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

Succeeds → **GitHub issue** (below). Fails (no GitHub remote, no auth) → **file fallback** (bottom of this page). Never ask the user which one; the repo answers it.

## Creating the map

The label only needs creating once per repo; the `|| true` keeps a second run quiet.

```bash
gh label create "wayfinder:map" --color 0E8A16 --description "Wayfinder map" 2>/dev/null || true

gh issue create \
  --title "Wayfinder: <short name>" \
  --label "wayfinder:map" \
  --body-file <scratchpad>/wayfinder-map.md
```

Keep the working copy of the body in the scratchpad (`wayfinder-map.md`) for the
whole session. Every update is: edit the file, push the whole file. Hand-editing
the body through a here-string loses the parts you did not retype.

```bash
gh issue edit <N> --body-file <scratchpad>/wayfinder-map.md
```

## Reading the map

Body plus metadata, no comments — this is the cheap read a resuming session starts with:

```bash
gh issue view <N> --json number,title,url,body,state -q .body
```

Save that output straight into the scratchpad file so later edits start from the live version:

```bash
gh issue view <N> --json body -q .body > <scratchpad>/wayfinder-map.md
```

The current step is the first `- [ ]` line under `## Map`:

```bash
grep -n -m1 '^- \[ \]' <scratchpad>/wayfinder-map.md
```

Comments (only when a step actually needs an earlier result):

```bash
gh issue view <N> --json comments -q '.comments[] | "\(.createdAt) \(.url)\n\(.body)\n"'
```

## Finding maps

```bash
gh issue list --label "wayfinder:map" --state open --json number,title,url
```

## Finishing a step

Post the result comment first, because the checklist line has to link to it:

```bash
gh issue comment <N> --body-file <scratchpad>/step-result.md
```

That prints the comment URL. Then tick the line in `wayfinder-map.md` and link it:

```markdown
- [x] research: screen capture on Wayland vs X11 — [result](https://github.com/<owner>/<repo>/issues/42#issuecomment-123456789)
```

and push the body back with `gh issue edit <N> --body-file …`.

For `implement:` steps, link the PR to the map so GitHub cross-references both ways — put `Part of #<N>` in the PR body (not `Closes`, which would close the whole map when one step merges):

```bash
gh pr create --title "<step title>" --body "Part of #<N>

<what changed>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

## Closing a finished map

Only when the destination is actually reached and the user agrees:

```bash
gh issue close <N> --comment "Destination reached: <one line>"
```

## File fallback

No GitHub remote → the map is a markdown file at `.wayfinder/<slug>.md`, committed
with the code. Same sections as the issue, with two differences:

- Step results are `## Results` subsections appended to the same file instead of comments; checklist lines link to the heading anchor (`— [result](#research-screen-capture)`).
- Finding maps is `ls .wayfinder/*.md`, and an open map is one with an unticked `- [ ]` line.

Commit the map file with each update so the history shows how the map moved:

```bash
git add .wayfinder/<slug>.md && git commit -m "docs(wayfinder): <what changed>"
```
