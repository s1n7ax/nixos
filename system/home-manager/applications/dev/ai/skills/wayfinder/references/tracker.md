# Tracker mechanics

Where the map physically lives, and the exact file commands.
Read this when creating a map, resuming one, or finishing a step.

Default is **local files, always**. A GitHub issue is opt-in only —
see the bottom section. Never create one unless the user explicitly asks.

## Map location

One directory per map, so a repo can hold several at once:

```
<repo-root>/.wayfinder/<slug>/map.md
```

- `<slug>` is a short kebab-case name for the effort (`screen-recorder`, `auth-migration`). Derive it from the destination; keep it under ~30 chars.
- The `.wayfinder/` dir is git-ignored globally — local-only scratch, never committed.
- Step assets (prototypes, research notes, drafts) live beside `map.md` in the same dir.
- Create it with `mkdir -p .wayfinder/<slug>` when it does not exist.

## Creating the map

Write `.wayfinder/<slug>/map.md` with Destination filled in and everything
else empty. That file is the live map from then on — every update edits it
in place. Tell the user the slug and path.

## Reading the map

Read the file — Destination, Requirements, Out of scope, Map. Do not read
every `## Results` subsection; zoom into one only when the current step
needs what it holds.

The current step is the first `- [ ]` line under `## Map`:

```bash
grep -n -m1 '^- \[ \]' .wayfinder/<slug>/map.md
```

## Finding maps

```bash
ls .wayfinder/*/map.md
```

An open map is one with an unticked `- [ ]` line. Exactly one map → take
it. More than one and no slug given → ask the user which.

```bash
grep -l '^- \[ \]' .wayfinder/*/map.md
```

## Finishing a step

Append one `### <Step line>` subsection per finished step under
`## Results`, then tick its checklist line and link the anchor:

```markdown
- [x] research: screen capture on Wayland vs X11 — [result](#research-screen-capture-on-wayland-vs-x11)
```

Anchors are GitHub-style: lowercase the heading, drop punctuation,
spaces → hyphens. Save the file once per wave — never leave one step
ticked and another lost.

For `implement:` steps, finish the code the way the repo finishes code
(tests, branch, PR) and put the PR link in the Results subsection. Do not
reference a map issue number — there isn't one in local mode.

## Closing a finished map

Only when the destination is actually reached and the user agrees: say so
and leave the file as the record. Delete `.wayfinder/<slug>/` only if the
user asks.

## GitHub opt-in (only on explicit request)

Create/mirror a map as a GitHub issue **only** when the user explicitly
asks ("put this on GitHub", "track it as an issue", etc.). The local file
stays the live map; the issue is a mirror, updated by pushing the file
body. Never pick this on your own; the repo's remote does not decide it.

```bash
gh label create "wayfinder:map" --color 0E8A16 --description "Wayfinder map" 2>/dev/null || true

gh issue create \
  --title "Wayfinder: <short name>" \
  --label "wayfinder:map" \
  --body-file .wayfinder/<slug>/map.md
```

Push updates with:

```bash
gh issue edit <N> --body-file .wayfinder/<slug>/map.md
```

Step results still live in the file's `## Results`; a result comment on
the issue is optional (`gh issue comment <N> --body-file <result-draft>`)
and the checklist line keeps pointing at the file anchor, not the comment.

For `implement:` steps in opt-in mode, link the PR to the map issue with
`Part of #<N>` in the PR body (not `Closes`, which would close the whole
map when one step merges). Resume with `/wayfinder <slug>` as usual —
read the file, not the issue.
