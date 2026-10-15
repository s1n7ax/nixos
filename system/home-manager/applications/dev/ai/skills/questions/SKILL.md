---
name: questions
description: Decide whether a question is worth the user's attention before it is asked, and ask the ones that are. Use whenever you are about to ask the user anything — in any skill or session — or when a skill tells you to ask. Runs each candidate through the dumbness score, blocks questions you can answer yourself, and defines the shape of one question plus how to use the agent's native ask-question tool.
---

# Questions

The user's attention is the scarcest resource in the session, and every question spends it — whether or not the answer was ever needed. This skill decides which questions reach the user, kills the rest, and defines how the survivors are asked.

Three rules hold the whole skill up. Everything below is detail.

1. **Ask only what is the user's to decide.** Facts you can fetch, defaults any competent engineer would pick, and choices that do not change the work are yours — decide them and move on.
2. **Score before you ask.** Run every candidate through the dumbness score. A high score means the question does not go to the user; it comes back to you to resolve.
3. **One decision per question.** Never bundle decisions, and never ask two things in one message.

## The dumbness score

Score every candidate before it reaches the user. Add the points for each flag it trips:

**Blockers — any one of these means the question does not reach the user:**

| Flag                   | Points | Meaning                                                                                      |
| ---------------------- | ------ | -------------------------------------------------------------------------------------------- |
| **Self-answerable**    | +3     | The code, the docs, a tool, or a spike can answer it.                                        |
| **Obvious default**    | +3     | One option is what any competent person would pick; the others are absurd or strictly worse. |
| **Already answered**   | +3     | The user said it, or it follows directly from what they said.                                |
| **No consequence**     | +3     | The answer changes nothing about what gets built or done.                                    |
| **Fact, not decision** | +3     | You are asking the user to supply something you should look up.                              |

**Softeners — cheap to fix, so sharpen before asking:**

| Flag                   | Points | Meaning                                                                             |
| ---------------------- | ------ | ----------------------------------------------------------------------------------- |
| **False dilemma**      | +1     | The options miss the real alternatives, or smuggle extra decisions into the choice. |
| **Speculative**        | +1     | The decision is not needed yet, or is outside the current scope.                    |
| **Cheaply reversible** | +1     | You can change the decision later at little cost.                                   |
| **Delegable**          | +1     | A subagent, a second read, or a short spike could settle it.                        |

**0 — ask it.** A real decision only the user can make.

**1–2 — sharpen first.** Fix the options, split the bundle, read the code, or spike it, then re-score. Ask only what reaches 0.

**3 or more — do not ask.** The question is not worth the user's attention. Resolve it yourself — decide with the obvious default, or go get the missing fact — then record what you chose and why, and carry on. Escalate only if you genuinely cannot proceed without the user, and then say plainly what blocks you.

The score gates the question, not the topic. A question can be weighty and still score 0; a question can sound reasonable and still score 3 because one option is nonsense. Score the question.

### Ask yourself first

For any question that scores 3 or more, answer these to yourself, in order, before giving up on it:

1. **What would I do if the user said nothing?** If you have an answer, do that.
2. **Is there a default any competent person would pick?** Then that is the answer.
3. **Does the answer change a single line of the work?** If not, do not ask.
4. **Can I get the answer from the code, the docs, or a tool?** Then get it.
5. **Am I asking because I am unsure, or because it is genuinely theirs?** Being unsure is not a reason to ask.

Only a question that survives all five is the user's to answer.

### What a dumb question looks like

> The voice should run as a background service so it is always available, or only while Neovim is open?

Nobody would tie a home-automation voice to an open editor. The second option is absurd, so the "choice" is not a choice: it scores +3 for an obvious default and never reaches the user. The agent picks the background service, notes the assumption, and moves on.

## Whose decision is it?

Each workflow has its own territory, but this skill's rules apply to every question asked in any of them. One test decides whether a question is in bounds:

> If we threw away every line of code and rebuilt it with different tools, would this answer still matter?

Yes → the user's world. It may be asked, if it survives the score.
No → implementation. Yours to decide; never ask.

## The shape of one question

1. **One decision, answerable in a word.** The options are direct answers to that one question. A topic holding several decisions becomes a chain: ask a gate question first, then only the branches its answer makes relevant.
2. **Explain first.** One plain sentence for the question itself, then enough context to see why it matters and what depends on the answer.
3. **At most 3 options, best first.** Think of every reasonable answer, then present only the top 3. For each: what it means in practice, why you would pick it, what it costs. Mark the recommendation and give the one-line reason.
4. **Keep the escape hatch.** The user can always answer in their own words. The agent's tool supplies it, or you add it in plain text (see below). It never smuggles in a second decision.

## Using the agent's ask-question tool

Prefer the native structured question tool when the agent has one. It keeps the answer short, renders the options, and makes "none of these" first-class.

- **Pi** — `ask_user_question`.
- **Claude Code** — `AskUserQuestion`.
- **Anything else** — its structured question tool if it has one; otherwise ask in plain text.

When the tool is available:

- **One decision per question.** The tool may accept several questions at once; that is not a licence to bundle. Do not use the multi-question form to sneak a second decision into the first.
- **2–3 options.** The recommendation goes first and is marked. Each option gets a short label and a description of the trade-off.
- **Do not author the escape hatch.** The tool appends its own "Type something" row. Adding a "None of these" option on top of it duplicates it.
- **The header is a topic, not a sentence.** A few words, not the whole question.
- **`multiSelect` only when several answers can be true at once.** Otherwise it is a single choice.
- **A preview only when the options are artifacts to compare** — a layout, a schema, a config — never for a plain preference.

When the tool is unavailable, ask in plain text: numbered options, recommendation first, and "None of these — let me explain" last.

## After you ask

Stop and wait. Then handle what comes back:

- **A listed option** — record it and move on.
- **Their own answer** — record their words; if it reshapes earlier answers, say so.
- **A question back at you** — answer it, then re-ask. If the reply shows the question missed the mark, rework it first — break it down, sharpen it, replace the options — then ask again.
- **"You decide" or silence** — take the recommendation, say which one you took, move on.

## Never

- Never ask a question that scores 3 or more on the dumbness score.
- Never ask for a fact you can look up.
- Never ask a question whose answer does not change the work.
- Never bundle several decisions into one question.
- Never present more than 3 options.
- Never ask more than one question per turn.
- Never author a "None of these" escape hatch when the tool already supplies one.
- Never present an option you already know is absurd; if it is absurd, drop it and decide.
