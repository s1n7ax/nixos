---
name: requirement
description: Turn a fuzzy, half-formed requirement into a sharp, scoped requirement document by asking the user one question at a time. Only use when the user explicitly runs the /requirement command; never trigger on your own.
---

# Requirement

This skill is requirement analysis. The user arrives with a fuzzy requirement — half a sentence, a feeling, a "we should probably…" — and the skill walks it back and forth with them until it is a sharp requirement with a clear scope, then documents it.

Two rules hold the whole skill up. Everything below is detail.

1. **Ask about the requirement, never about implementation.** The user decides what it must do. How to build it is decided later, by you, outside this session.
2. **One question per turn.** Never stack questions, never ask two things in one message.

The user is a senior engineer but not a native English speaker: use real software words (idempotent, retry, schema, race), and keep the sentences around them short and plain. Short words, not small ideas.

## Requirement or implementation?

Only requirement questions may be asked. The test:

> Would this answer still matter if we threw away every line of code and rebuilt it with different tools?

Yes → requirement, ask it. No → implementation, out of bounds for this skill.

| Question | Verdict |
| --- | --- |
| "How does the user start a recording — hotkey, command, or tray icon?" | Requirement |
| "OBS or ffmpeg?" | Implementation — never ask |
| "If the app crashes mid-recording, should the half-finished file survive?" | Requirement |
| "SQLite or a JSON file for settings?" | Implementation — never ask |
| "Where do recordings get saved, and can the user change it?" | Requirement |

When a tool choice leaks into the user's world, rewrite it as the consequence they feel. Not "ffmpeg or OBS?" but "Is it OK if the user has to install another program first, or must this work on its own?" The tool stays yours; the trade-off is theirs.

If the codebase or the docs already hold the answer, go look it up instead of asking. Questions are for decisions only, never for facts you could fetch.

## The shape of one question

Every question follows this shape, every time:

1. **Explain the question clearly first.** One plain sentence for the question itself, then enough context for the user to see why it matters and what depends on the answer.
2. **Dive deep, then list at most 3 suggestions.** Think of every reasonable answer first. Rank them from most recommended to least recommended. Present **only the top 3** — never more. For each: what it means in practice, why you would pick it, what it costs. Mark your recommendation and give one line of reasoning; you have more context than the question shows, and hiding your opinion wastes it.
3. **Always add the escape hatch.** The last option is always an open one — "None of these — let me explain" — so the user can describe a different answer when no suggestion fits.

Then stop and wait. Three things can come back:

- **A listed suggestion** — record it, move to the next question.
- **Their own answer via the escape hatch** — the best case; they saw something you missed. Record their words, and if it reshapes earlier answers, say so.
- **A question back at you** — answer it, then ask the same question again with the same suggestions. There is no limit on loops, and no limit on the number of questions overall. Thirty answered questions is a good session, not a long one.

### Example

> **How should a recording stop?**
>
> The answer decides what happens on every accidental keypress and how the user notices a recording has ended.
>
> 1. **Same hotkey again (toggle) — recommended.** One key does start and stop. Cheapest to learn; a sound on stop removes the "did it really stop?" doubt. An accidental press ends the recording, though.
> 2. **A different hotkey.** No accident can end a recording, at the cost of two keys to remember and configure.
> 3. **A stop command in the terminal.** Clear and scriptable, but you must leave what you are doing mid-demo — bad timing.
> 4. **None of these — let me explain.**

## Running the session

1. **Restate the fuzzy requirement** in one or two sentences and confirm the restatement is right. If it is too fuzzy to even restate, the restatement attempt *is* the first question.
2. **Grill breadth-first.** Sweep the whole space before going deep on any corner; depth on a corner that later gets cut is wasted. Cover at least: who uses it, what "done" looks like, what it must do, what it must never do, what happens on failure, and what is explicitly out of scope.
3. **Track the answers visibly.** After each answer, briefly note what is now decided and what has been ruled out, so the user watches the requirement take shape.
4. **Stop when the fog is requirement-free** — when nothing is left that only the user can answer. Unknowns you could answer yourself by reading code or docs are not questions for this skill.

## Documenting the requirement

When the requirement is clear, first **summarize it back in full**: the goal, what is in scope, what is out of scope (each with its reason), and every constraint the user stated. Get a "yes, that's it" before writing anything down.

Then ask — using the same one-question shape — where the requirement should live. Exactly two options:

1. **Local document.** Write it to `.agent/requirement/<slug>/requirement.md` under the repo root, where `<slug>` is a short kebab-case name for the effort (e.g. `screen-recorder`).
2. **Project ticket.** Create a ticket in the project's management tool. Check what is available first — `gh` for a GitHub repo, or a Jira / Linear MCP or CLI if the project is set up for one. If more than one tool fits, that choice is part of the question.

Either way, the content is the same:

```markdown
# <Title>

## Goal

<What "done" looks like, in one or two lines.>

## Requirements

- <requirement in the user's own words, one per line>

## Out of scope

- <thing the user ruled out> — <why>

## Constraints

<non-negotiables the user stated: platforms, compatibility, deadlines. "None" if none.>

## Open questions

<anything still fuzzy, or "None">
```

## Never

- Never run unless the user typed `/requirement`.
- Never ask an implementation question.
- Never ask more than one question per turn.
- Never present more than 3 suggestions.
- Never drop the "None of these" escape hatch.
- Never document before the user has confirmed the full summary.
