---
name: wayfinder
description: Chart a big, foggy piece of work as ONE ticket holding the whole roadmap as a checklist, then walk that checklist one step per session. Only use when the user explicitly runs the /wayfinder command; never trigger on your own.
---

# Wayfinder

A big idea has arrived and the way to it is fogged. Wayfinder charts that way as **one ticket** — the map — and then walks it, **one step per session**, until the thing is built.

Three rules hold the whole skill up. Everything below is detail.

1. **One ticket holds everything.** The map, the requirements, every answer, every step's report. Nothing lives anywhere else.
2. **Ask about requirements, never about implementation.** The user decides what it must do. You decide how to build it.
3. **One wave per session, then stop.** A wave is either one step you walk with the user, or up to three independent steps handed to subagents at once. Every step is sized to fit one fresh ~100K-token context. The wave finishes, the results go back to the ticket, and you hand off.

## Why one wave per session

Long sessions rot: by step four the context is full of step one's dead ends and the work gets worse. The ticket is the memory instead of the context window. So a session loads the map, does exactly one step, writes what it learned back, and ends clean — the next session starts fresh and loses nothing, because the ticket has it all.

A subagent is a fresh context too. That is why `research:` and `implement:` steps — the ones with no user in them — can run side by side: each subagent loads the map itself, does its one step, and hands back a report. Your context sees the reports, not the dead ends behind them. The rule is not loosened, only widened: one wave of fresh contexts per session, then stop.

This is also why the ticket is created **early**, before the requirements are finished: if the session dies mid-grilling, the answers already given are safe on the ticket.

## The map ticket

One GitHub issue, labelled `wayfinder:map`, titled `Wayfinder: <short name>`. See `references/tracker.md` for the exact `gh` commands and for the markdown-file fallback when the repo has no GitHub remote.

```markdown
## Destination

<What "done" looks like, in one or two lines. Every session reads this first.>

## Requirements

<!-- grows one line per answered question; this is the spec -->

- <requirement in the user's own words>

## Out of scope

- <thing the user ruled out> — <why>

## Open questions

<!-- requirement fog: questions you know are coming but cannot phrase sharply yet -->

## Map

- [x] grill: how recording starts and stops — [result](<comment link>)
- [x] research: screen capture on Wayland vs X11 — [result](<comment link>)
- [ ] implement: hotkey listener
- [ ] implement: encoder pipeline
- [ ] implement: mux audio into the output — needs: encoder pipeline

## Implementation notes

<!-- decisions YOU made, not the user; listed so they can object -->

- ffmpeg over OBS — already a dependency, no GUI needed
```

A step that cannot start before another step's result exists ends with `— needs: <the other step's name>`. No marker means nothing blocks it, and unblocked solo steps run side by side — see **Running steps in parallel**.

Each finished step gets a **comment** on this same issue holding its full result, and the checklist line is ticked and linked to that comment. The body stays a low-resolution index; the comments hold the detail. That way a resuming session reads one body to know where it is, and zooms into comments only when it needs them.

## Step types

The prefix on a checklist line tells the next session what kind of work it is, so it can start without asking.

| Prefix | What happens | Who drives |
| --- | --- | --- |
| `grill:` | Requirement questions to the user, one at a time (see below) | with the user |
| `research:` | Read docs, APIs, the codebase; write findings as a comment | you alone |
| `prototype:` | Build something cheap and throwaway so the user can react to something real | with the user |
| `task:` | Manual work that unblocks a decision — sign up for a service, provision access, move data | whoever can do it |
| `implement:` | Write the real code, test it, commit, open a PR | you alone |

The two rows that say **you alone** — `research:` and `implement:` — are the ones a subagent can run. The other three need the user in the room, so they run in your session, one at a time.

Size every step to one fresh session. If a step turns out bigger than that, **do not push through** — split it into sub-steps on the map, tick nothing, and hand off. A half-done step that was never split is the main way a map goes wrong.

## Running steps in parallel

When the next unticked steps are `research:` or `implement:` and do not feed each other, run them at once as subagents instead of one per session.

**Pick the wave.** Start at the first unticked step. Walk down `## Map` taking steps while every one is `research:` or `implement:` and none `needs:` a step that is still unticked. Stop at **three**. Three is a ceiling, not a target — a wave of one is normal.

Any other prefix ends the wave: a `grill:`, `prototype:` or `task:` step is walked alone, in your session, with the user.

**Spawn them together** — one message, one `Agent` call per step, or they run one after another instead of side by side. Use `subagent_type: "general-purpose"`, and give every `implement:` agent `isolation: "worktree"` so two of them never write the same file at once.

Each brief carries what the agent cannot get for itself, and nothing more:

- the map issue number, and the instruction to read its body with `gh issue view <N> --json body -q .body`
- the checklist line it owns, copied verbatim
- which earlier comments to read, if its step needs one
- **it must not touch the issue** — no comment, no `gh issue edit`. You own the ticket; concurrent writers lose each other's edits.
- what to hand back: what it did, what it found, every decision it made that the user did not, and for `implement:` the PR link
- if its step turns out bigger than one context, it stops and hands back the split it would make instead of pushing through

**Collect, then write once.** When every agent in the wave has reported, post one comment per step, then tick all those lines and push the body a single time. A wave must never leave one step ticked and another lost.

If an agent hands back a split instead of a result, do not tick that line — replace it on the map with the sub-steps it named, and say so in the hand-off.

Then stop. A finished wave ends the session exactly as a finished step does.

## Asking questions

This is the part that makes wayfinder feel different. The user is a senior engineer but not a native English speaker: use real software words (idempotent, retry, schema, race), and keep the sentences around them short and plain. Short words, not small ideas.

### Requirement or implementation?

Only requirement questions may be asked. The test:

> Would this answer still matter if we threw away every line of code and rebuilt it with different tools?

Yes → requirement, ask it. No → implementation, decide it yourself and log it under **Implementation notes**.

| Question | Verdict |
| --- | --- |
| "How does the user start a recording — hotkey, command, or tray icon?" | Requirement |
| "OBS or ffmpeg?" | Implementation — decide it |
| "If the app crashes mid-recording, should the half-finished file survive?" | Requirement |
| "SQLite or a JSON file for settings?" | Implementation — decide it |
| "Where do recordings get saved, and can the user change it?" | Requirement |
| "One process or two?" | Implementation — decide it |

**When a tool choice leaks into the user's world, rewrite it as the consequence they feel.** Not "ffmpeg or OBS?" but "Is it OK if the user has to install another program first, or must this work on its own?" The tool stays yours; the trade-off is theirs.

**If the codebase or the docs already hold the answer, go look it up.** Questions are for decisions only, never for facts you could fetch.

### The shape of one question

Ask **one** question per turn, and follow this shape every time:

1. **Say the question in one plain sentence.**
2. **Explain each option:** what it means in practice, why you would pick it, what it costs.
3. **Give your recommendation** and one line of reasoning. You have more context on the problem than the phrasing shows; hiding your opinion wastes it.
4. **Ask it again with `AskUserQuestion`** — same question, same options. The user must not have to scroll up to see the choices after reading the explanation.

In the `AskUserQuestion` call: 2–3 real options plus a final option labelled **"Explain more first"**. Each option's `description` is one "Pick this if…" line. Never write the options as if they were the only answers — the tool always adds an **Other** box where the user types their own, and your options are just the ones you could think of.

Three things can come back:

- **A listed option** — record it and move on.
- **Other, with an answer of their own** — this is the best case. The user saw something you missed. Record their words as the requirement, and if it changes the shape of the map, say so.
- **Explain more first, or a question typed into Other** — answer it, then ask the same question again with the same options. There is no limit on how many times this can loop, and no limit on the number of questions overall. A map with thirty answered requirement questions is a good map.

**Use `preview` whenever the options differ in something you can show**: a CLI session, a config file, a screen layout, a JSON payload, an event order. A senior engineer reads a concrete shape faster than a paragraph about it.

### Example

> **How should a recording stop?**
>
> - **Same hotkey again (toggle).** One key does start and stop. Cheapest to learn, but if the key is pressed by accident the recording ends and you may not notice.
> - **A different hotkey.** Start and stop are separate keys, so no accident ends the recording. Two keys to remember, and one more thing to configure.
> - **A stop command in the terminal.** Clear and scriptable, but you must leave what you are doing and find a terminal — bad in the middle of a demo.
>
> I would take the toggle: one key, and a sound on stop removes the "did it really stop?" doubt.

…then the same question and the same three options go into `AskUserQuestion`, plus *Explain more first* — and the user can always ignore all four and type a fourth way to stop a recording into *Other*.

Record each answer on the ticket under **Requirements** right away — one line, in the user's words, not yours. Do not batch them up until the end; a dead session must not lose an answer.

## Charting a new map

The user arrives with a loose idea and no map.

1. **Find the destination.** One requirement question: what does "done" look like? Use the question shape above.
2. **Create the ticket now** with Destination filled in and everything else empty. Everything from here is written to it as it happens. Tell the user the issue number and link.
3. **Grill for requirements, breadth-first.** Sweep the whole space before going deep on any corner; depth on a corner that later gets cut is wasted. After each answer, append it to **Requirements**, and write anything newly visible but still blurry into **Open questions**. Anything the user rules out goes to **Out of scope** with its reason.
4. **Stop grilling when the fog is requirement-free** — when nothing is left that only the user can answer. Remaining unknowns that *you* could answer by reading or trying are research steps, not questions.
5. **Write the `## Map` checklist**: the ordered steps from here to the destination, each with a type prefix and sized to one session. End a step with `— needs: <step name>` when it cannot start before that step's result exists; leave the rest unmarked, because unmarked solo steps are what a later session runs in parallel. Chart only what you can see; more steps get added as fog clears.
6. **Stop.** Charting is a whole session's work. Do not start step one — tell the user to run `/wayfinder <issue>` in a fresh session.

## Resuming a map

The user runs `/wayfinder <issue number or URL>`, or `/wayfinder` alone.

1. **Find the map.** With an argument, load that issue. Without one, list open `wayfinder:map` issues in the repo; if there is exactly one, take it, otherwise ask which.
2. **Read the body only** — Destination, Requirements, Out of scope, Map. Do not read every comment; zoom into a comment only when the current step needs what it holds.
3. **Take the wave.** The first `- [ ]` line in `## Map` is the step. Its prefix decides what happens next — no asking the user what to work on, and no re-deciding the order. If it is `research:` or `implement:`, take the following such lines that nothing unticked blocks too, up to three, and run them as subagents (see **Running steps in parallel**). Any other prefix: that one step, alone, in this session.
4. **Do that wave, and only that wave.**
5. **Report it** (below), then hand off.

If the map has no unticked steps: check whether the destination is actually reached. If it is, say so and offer to close the issue. If it is not, the fog moved — chart the next steps and stop.

## Finishing a step

Every step ends the same way, whatever its type:

1. **Post a comment** on the map issue — one per step in the wave: what was done, what was found, and every decision made that the user did not make. For `implement:`, include the PR link.
2. **Tick the checklist lines** in the body, each linked to its own comment, and push the body once for the whole wave.
3. **Update the rest of the body**: new requirements learned, fog that is now sharp enough to become steps, anything now out of scope, implementation decisions under **Implementation notes**.
4. **Hand off** — end the session with the issue link, one line per step on what was done, and the next wave's steps, then tell the user to start a fresh session (`/clear`, then `/wayfinder <issue>`). Resist doing "just one more" step: the next session's clean context is worth more than the minutes saved.

For `implement:` steps, finish the code the way this repo finishes code — tests run, committed on a branch, PR opened and linked back to the map issue. A subagent does this inside its own worktree, so its branch and PR are its own. If the repo has skills for testing or committing (`/tdd`, `/git-commit`, `/code-review`), use them; the map does not replace how this repo works.
