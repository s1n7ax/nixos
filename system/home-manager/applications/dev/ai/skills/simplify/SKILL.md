---
name: simplify
description: Clean up changed code without changing intended behavior or deviating from the documented requirement and implementation plan. Review for reuse, simplification, efficiency, and architectural alignment, then apply justified fixes. Quality only; does not hunt for bugs. Use when asked to simplify, refactor, clean up, or reduce complexity in code.
disable-model-invocation: true
---

# Simplify

Review and improve code quality while preserving intended behavior and aligning the implementation with its documented requirement and implementation plan. Identify duplication, unnecessary complexity, wasted work, and architectural inconsistencies. Apply justified improvements directly.

Usage: `/simplify [target]`

## Phase 0 — Establish scope and context

Identify the code to review:

- If a target is provided, review that target.
- Otherwise, inspect the current changes using the relevant version-control diff.
- Include uncommitted changes when present.
- If no changes are available, ask for a target or identify a reasonable scope from the current context.

Locate the relevant goal documentation under `.goal/<goal_name>/`:

- Requirement: `.goal/<goal_name>/requirement/requirement.md`
- Implementation plan: `.goal/<goal_name>/plan/plan.md`

Determine the applicable goal from the target, changed files, branch context, or surrounding discussion. If multiple goals are plausible, ask for clarification rather than guessing.

Read both documents before making changes. If either document is missing or ambiguous, identify the limitation and avoid assuming undocumented requirements or architectural decisions.

Treat the identified code changes as the primary review scope. Use the requirement and implementation plan as constraints for evaluating the implementation.

## Phase 1 — Review

Review the implementation from four perspectives. Use independent review passes or parallel agents when available and useful.

### Requirement alignment

- Verify that the implementation satisfies the documented requirements.
- Identify unnecessary functionality, missing implementation details, and behavior that conflicts with the requirements.
- Preserve explicitly required behavior, constraints, interfaces, and compatibility.
- Do not expand the feature scope or reinterpret requirements during cleanup.

### Implementation-plan alignment

- Verify that the implementation follows the documented architecture, responsibilities, interfaces, and sequencing where relevant.
- Identify deviations that introduce unnecessary complexity, duplicate mechanisms, or violate the intended design.
- Prefer the abstractions and shared mechanisms specified in the plan.
- Do not silently redesign or override the plan. If the plan appears inconsistent with the requirement or existing constraints, report the conflict instead of inventing a resolution.

### Reuse and simplification

- Identify functionality that duplicates existing code, utilities, abstractions, or established patterns.
- Remove unnecessary complexity, redundant state, repeated logic, excessive nesting, avoidable indirection, and obsolete code.
- Prefer straightforward implementations over clever or overly generic solutions.
- Search the surrounding codebase before introducing new helpers or abstractions.

### Efficiency and architecture

- Identify unnecessary computation, repeated I/O, avoidable allocations, sequential execution of independent operations, and work performed on critical paths.
- Evaluate resource lifetimes and memory retention where relevant.
- Check whether responsibilities belong at the current level or in an existing shared mechanism.
- Avoid speculative optimizations and architectural changes without a concrete benefit.

For every actionable finding, identify:

- File and relevant code location.
- The quality issue and its maintenance, complexity, or performance cost.
- How it relates to the requirement or implementation plan.
- A concrete improvement that preserves the intended behavior and documented design.

Do not manufacture findings to fill categories. Distinguish confirmed deviations from potential improvements.

## Phase 2 — Consolidate and apply

1. Consolidate duplicate findings.
2. Validate each proposed improvement against the requirement, implementation plan, existing implementation, and surrounding code.
3. Apply justified fixes directly.
4. Prefer small, focused changes over broad rewrites.
5. Preserve public interfaces, compatibility, and required behavior unless the documentation explicitly calls for a change.
6. Do not introduce features, abstractions, dependencies, or architectural changes outside the documented scope.
7. If the existing implementation conflicts with the requirement or plan, make only changes that can be justified by the documentation. Do not silently modify the requirement or plan to match the code.
8. If a conflict prevents a safe decision, stop that part of the refactoring and explain the conflict.
9. Do not turn this task into a general bug hunt. Report unrelated correctness issues separately without expanding the cleanup scope.

## Phase 3 — Verify

1. Review the final diff and confirm every change has a concrete quality benefit.
2. Verify that the implementation remains aligned with the requirement and implementation plan.
3. Run relevant tests, formatters, and static checks when available.
4. Confirm that intended behavior, public interfaces, and compatibility remain unchanged.
5. Revert unjustified changes and report verification that could not be completed.

Do not claim tests or checks passed unless they were actually run and passed.

## Phase 4 — Report

Summarize:

- Improvements applied.
- Relevant requirement or implementation-plan alignment.
- Tests and checks performed, including failures or checks not run.
- Any unresolved conflicts or deviations requiring a decision.

Do not report changes that were not made or claim compliance that was not verified.
