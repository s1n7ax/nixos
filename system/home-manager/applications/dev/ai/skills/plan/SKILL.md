---
name: plan
description: Turn a confirmed requirement into an implementation plan another agent can execute with no questions asked. Starts by analyzing the code — asking for access first when the code is out of reach — and asks the user only as a last resort, about approach forks, significant stretches, requirement gaps, and unverified assumptions — one question at a time. Only use when the user explicitly runs the /plan command; never trigger on your own.
---

# Plan

This skill is implementation planning. The user arrives with a sharp requirement — usually written by the `/requirement` skill — and the skill works out how to build it: explore the code, find the viable ways, settle every decision that needs the user's taste or risk appetite, and write a plan another agent can execute with no questions asked.

Three rules hold the whole skill up. Everything below is detail.

1. **Code first, questions last.** Analyzing the code is always the first move. A question is the last option — only when the code, the docs, and your tools cannot settle it.
2. **Ask only the four allowed question types.** Every other decision — tools, files, patterns, defaults — you make yourself by reading the code and docs. The one exception is asking for code access (see Code first).
3. **One question per turn.** Never stack questions, never ask two things in one message.

The user is a senior engineer but not a native English speaker: use real software words, and keep the sentences around them short and plain.

## Code first

Jump straight into the code. Read every project the requirement touches and work out the plan from what is there. Do not ask the user anything the code can tell you.

### When the code is out of reach

If a project the requirement touches is not readable, getting access comes first — before any planning question.

1. **Use what already works.** A local checkout, a connected MCP for the code host, or an authenticated CLI such as `gh` that can read the repo. If one works, read the code and carry on — no question.
2. **Otherwise, ask for access.** One question, in the usual shape. Suggestions, ranked:
   - **Clone the project — recommended.** Full, fast local reads.
   - **Add an MCP** for the code host.
   - **Set up a CLI** such as `gh` to read the repo remotely.
3. **Never plan blind.** Do not guess the code, and do not replace reading it with questions. If access cannot be had, say which project is blocked and stop.

## The four allowed question types

### Type 1 — Fork in the road

Two or more clearly viable approaches exist, and every one of them satisfies the requirement. Ask which one the user prefers.

- Always rank the suggestions by **most maintainable, most scalable, simplest first**. Mark your recommendation and say why in one line.
- The user may request prototypes for one or more options instead of picking — see the Prototypes section.

### Type 2 — Significant stretch

The change costs something big or risky. **Always ask**, even when only one way exists — because the real question is "is this stretch acceptable?" The triggers:

- The existing architecture cannot deliver the requirement: a breaking change, a new dependency, a new service or project, a schema migration, removing existing behavior.
- The security or permission surface grows: new secrets, broader permissions, a new exposed endpoint, handling sensitive data for the first time.
- The change crosses an ownership boundary: it touches a project owned by someone else or shared with other efforts.

The user may opt out. When they do, update the requirement document: move the unachievable part into **Out of scope** with the reason (e.g. "full-text search — rejected, new dependency was too big a stretch"), then re-plan around what remains.

### Type 3 — Requirement gap

Planning reveals the requirement itself is silent on something that forks the plan — a decision no codebase exploration can settle. Ask it, framed as the consequence the user feels (the same framing rule as `/requirement`), then write the answer back into the requirement document — under **Requirements** or **Constraints**, in the user's words — and continue planning.

If the gap unravels the requirement itself rather than a corner of it, do not patch it one question at a time: name the gap, tell the user it needs another `/requirement` pass, and stop until it is resolved.

### Type 4 — Unverified assumption

The plan hinges on a technical claim you cannot verify from the code or docs ("the library's webhook retries at least once"). Ask permission to spike it before committing the plan to that path.

- Spike rules match prototypes: minimal, disposable, never on the main branch. Branch: `<project>_spike_<slug>` in the affected project.
- Report the finding, then continue planning with facts. A disproven assumption usually surfaces a new Type 1 or Type 2 question — ask it.

### Everything else is yours to decide

The gate test for any decision:

> Could a strong engineer, given this requirement and this codebase, decide this without the user's taste or risk appetite?

Yes → decide it yourself, silently. No → it must fit one of the four types to be asked. If it fits none, decide it yourself and record it in the plan's Decisions section.

Never ask for facts you could fetch. If the code or docs hold the answer, go read them. Before any question, check the code, the docs, and your tools first — asking is the last option.

## The shape of one question

Every question follows this shape, every time:

1. **Explain the question clearly first.** One plain sentence for the question itself, then enough context to see why it matters and what depends on the answer.
2. **Dive deep, then list at most 3 suggestions.** Think of every reasonable answer first. Rank them — most maintainable, most scalable, simplest first. Present **only the top 3**. For each: what it means in practice, why you would pick it, what it costs. Mark your recommendation.
3. **Always add the escape hatch.** The last option is always "None of these — let me explain".

Then stop and wait. Four things can come back:

- **A listed suggestion** — record it, move on.
- **Their own answer via the escape hatch** — record their words; if it reshapes earlier decisions, say so.
- **A prototype request** — run the Prototypes flow, then come back to this same question with the results.
- **A question back at you** — answer it, then ask the same question again. No limit on loops.

### Example — Type 1

> **Where should request validation live?**
>
> All three spots satisfy the requirement; they differ in how much code moves and who owns the rule.
>
> 1. **In the existing shared schema package — recommended.** One definition, both projects import it. Simplest change, and the rule cannot drift between projects. Cost: a version bump of the shared package.
> 2. **In each project separately.** No cross-project dependency, but the rule now exists twice and will drift.
> 3. **In a new validation service.** Cleanest separation and scales to future projects, but a new deployable to run and monitor — the most moving parts by far.
> 4. **None of these — let me explain.**

### Example — Type 2

> **The search requirement needs a real index, and the current in-memory store cannot provide one. The only viable path adds a new dependency (a search engine) and a new service in docker-compose. Is that stretch acceptable?**
>
> 1. **Yes, add it — recommended.** The requirement explicitly demands typo-tolerant search; no in-process trick delivers that.
> 2. **No — cut search back to exact filtering on existing fields.** The requirement document gets "typo-tolerant search" moved to out of scope, with the reason: new dependency rejected.
> 3. **None of these — let me explain.**

## Running the session

1. **Load the requirement.** If the user gave a path or ticket, read it. Otherwise look in `.agent/requirement/*/requirement.md`; if there are several or none, picking which one is the first question.
2. **Analyze the code before asking anything.** If a project is out of reach, get access first (see Code first). Explore every project the requirement touches. Build the full list of viable approaches and the decisions each one forces — the first question must already be informed.
3. **Ask breadth-first.** Settle the big forks and stretches in dependency order before any detail; detail on an approach that later gets rejected is wasted.
4. **Track decisions visibly.** After each answer, briefly note what is now decided and what has been ruled out.
5. **Stop when nothing is left that needs the user** — when every remaining decision passes the gate test as yours to make.

## Prototypes

When the user asks for prototypes on a fork:

1. **Confirm the setup in one question:** which options to prototype, and the selection criteria. Propose criteria (e.g. meets the requirement, least code, fewest moving parts, performance); the user may define their own.
2. **Branch per project per prototype.** For option `<n>` touching project `<project>`, create branch `<project>_proto_<n>` in that project's repo. Prototype 1 touching projects `api` and `web` → branches `api_proto_1` and `web_proto_1`. Never prototype on the main branch.
3. **Build the minimum that exercises the criteria.** Prototype code is disposable evidence, not the start of the implementation.
4. **Report and let the user pick.** Evaluate each prototype against the criteria, give your recommendation, and the user picks the winner. Record the losers in the plan's Decisions as rejected, with the measured reason. Prototype branches stay until the user deletes them.

## Writing the plan

First **summarize the plan back in full**: the chosen approach, every decision with its reason, the changes per project in execution order, and what is explicitly out. Get a "yes, that's it" before writing anything down.

The plan lives next to the requirement it implements: a local requirement doc gets `plan.md` in the same directory; a ticket gets the plan added to the ticket.

```markdown
# Plan: <title>

Implements: <path or link to the requirement>

## Decisions

- **<decision>** — <why>. Rejected: <alternatives> (<why rejected>).

## Changes

Ordered in execution order. One step = one change: what changes, where, and
which requirement it serves. Words, file paths, and symbol names — never code.

### <project name>

1. <change> — <requirement it serves>
2. ...

### <project name>

1. ...

## Verification

- <observable check that proves one requirement item — one per item>

## Non-goals

- <tempting nearby work that is explicitly not part of this plan>
```

### The no-questions test

Before writing, check every step: could an agent that never saw this conversation execute it without choosing anything? If a step forces a choice, the plan is not done — make the choice yourself, or ask it if it fits one of the allowed types.

### Multiple projects

Group changes per project. When a step in one project depends on a step in another, say so explicitly in the step text — the executing agent must see the dependency order without guessing.

## Never

- Never run unless the user typed `/plan`.
- Never ask a planning question before analyzing the code.
- Never ask a question outside the four allowed types — asking for code access is the only exception.
- Never ask more than one question per turn.
- Never present more than 3 suggestions.
- Never drop the "None of these" escape hatch.
- Never put code snippets in the plan.
- Never implement the plan in this session — prototypes on `_proto_` branches are the only exception.
- Never write the plan before the user has confirmed the full summary.
