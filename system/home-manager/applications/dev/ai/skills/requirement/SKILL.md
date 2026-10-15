---
name: requirement
description: Turn a fuzzy, half-formed requirement into a sharp, scoped requirement document by asking the user one question at a time. Only use when the user explicitly runs the /requirement command; never trigger on your own.
disable-model-invocation: true
---

# Requirement

This skill is requirement analysis. The user arrives with a fuzzy requirement — half a sentence, a feeling, a "we should probably…" — and the skill walks it back and forth with them until it is a sharp requirement with a clear scope, then documents it.

Three rules hold the whole skill up. Everything below is detail.

1. **Ask about the requirement, never about implementation.** The user decides what it must do. How to build it is decided later, by you, outside this session.
2. **Every question passes the `questions` skill.** It owns the dumbness score, the shape of one question, and the ask-question tool. This skill adds only what is requirement-specific.
3. **One question per turn.** Never stack questions, never ask two things in one message.

## Requirement or implementation?

The test for every question:

> Would this answer still matter if we threw away every line of code and rebuilt it with different tools?

Yes → requirement, ask it. No → implementation, out of bounds for this skill.

| Question                                                                   | Verdict        |
| -------------------------------------------------------------------------- | -------------- |
| "How does the user start a recording — hotkey, command, or tray icon?"     | Requirement    |
| "OBS or ffmpeg?"                                                           | Implementation |
| "If the app crashes mid-recording, should the half-finished file survive?" | Requirement    |
| "SQLite or a JSON file for settings?"                                      | Implementation |
| "Where do recordings get saved, and can the user change it?"               | Requirement    |

When a tool choice leaks into the user's world, rewrite it as the consequence they feel. Not "ffmpeg or OBS?" but "Is it OK if the user has to install another program first, or must this work on its own?"

If the code or docs hold the answer, look it up — questions are for decisions only, never for facts you could fetch.

## Asking the question

The dumbness score, the shape of one question, and the agent's ask-question tool all live in the `questions` skill — follow it for every question this session asks. Requirement adds one rule on top: the question must be about the requirement, and it must still answer exactly one decision. A question that scores 3 or more is never asked; decide it yourself, note the assumption, and carry on.

## Running the session

1. **Restate the fuzzy requirement** in one or two sentences and confirm the restatement is right. If it is too fuzzy to even restate, the restatement attempt _is_ the first question.
2. **Grill breadth-first.** Sweep the whole space before going deep on any corner; depth on a corner that later gets cut is wasted. Cover at least: who uses it, what "done" looks like and how anyone would observe it, what it must do, what it must never do, what happens on failure, and what is explicitly out of scope.
3. **Track the answers visibly.** After each answer, briefly note what is now decided and what has been ruled out.
4. **Stop when nothing is left that only the user can answer.**

## Documenting the requirement

When the requirement is clear, first **summarize it back in full** — every section of the document below, as it will be written. Get a "yes, that's it" before writing anything down.

Then ask where the requirement should live. Check first which project management tools are available — `gh` for a GitHub repo, or a Jira / Linear MCP or CLI if the project is set up for one. The suggestions:

1. **Local document.** Write it to `.agent/goals/<goal>/requirement/requirement.md` under the repo root, where `<goal>` is a short kebab-case description of what we are trying to achieve (e.g. `record-screen-demos`).
2. **Project ticket.** Create a ticket in the project's management tool — one suggestion per available tool.

Either way, the content is the same:

```markdown
# <Title>

## Goal

<What "done" looks like, in one or two lines.>

## Requirements

- <requirement in the user's own words, one per line>

## Acceptance criteria

- <observable outcome that proves a requirement is met — something a person or a check can see or run, not an intention. At least one per requirement.>

## Out of scope

- <thing the user ruled out> — <why>

## Constraints

<non-negotiables the user stated: platforms, compatibility, deadlines. "None" if none.>

## Open questions

<only unknowns that depend on something outside this session — a third party, a future event, a decision the user explicitly deferred. "None" if none.>
```

## Handing off to the next step

When `/ship` is driving this skill, skip this section — `/ship` moves on by itself.

Once the requirement document is saved, the workflow's next step is `/plan <goal>`, where `<goal>` is the goal's directory name (or the kebab-case name used for a ticket).

1. **Tell the user** the next step: run `/plan <goal>`.
2. **Copy the command to the clipboard** so the user can paste it: run `printf '%s' '/plan <goal>' | wl-copy` (Wayland; fall back to `xclip -selection clipboard` or `xsel --clipboard` when wl-copy is unavailable).
3. **Confirm the copy worked** — say the command is on the clipboard.

## Never

- Never run unless the user explicitly invoked this skill or `/ship`.
- Never ask an implementation question.
- Never ask a question that scores 3 or more on the `questions` skill's dumbness score.
- Never ask more than one question per turn.
- Never bundle multiple decisions into one question's options — each option must answer the question as asked, not add extra scope rulings on top.
- Never break a `questions` skill rule — the option cap, the escape hatch, or the ask-question tool.
- Never document before the user has confirmed the full summary.
- Never leave an open question in the document that could have been asked and answered during the session.
