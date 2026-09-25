---
name: todo-comments
description: Use whenever writing or requested to add a TODO, FIXME, or HACK marker in code. Ensures every TODO is backed by an issue tracker link (GitHub, Jira, Linear, etc.) and written as a doc comment in the host language's convention.
---

# TODO Comments

## Steps

1. Create an issue in the project's tracker (GitHub, Jira, Linear, etc.) for the work first
2. Write the TODO as a doc comment (`/** */`, `"""..."""`, `///`, or the language equivalent) with the issue URL on the next line

## Why

A TODO without a tracked issue is almost always a TODO forever — nobody greps through source to find them. Linking to an issue puts the context (why it matters, priority, owner) somewhere searchable and actionable.

## Examples

TypeScript / JavaScript:

```ts
/**
 * TODO: Implement caching layer
 * <issue-tracker-url>  (e.g. https://github.com/user/repo/issues/123, https://linear.app/team/issue/ABC-123, https://jira.example.com/browse/PROJ-123)
 */
```

For other languages, use the idiomatic doc-comment form.
