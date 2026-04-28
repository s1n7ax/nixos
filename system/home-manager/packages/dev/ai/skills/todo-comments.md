---
name: todo-comments
description: Use whenever writing or requested to add a TODO, FIXME, or HACK marker in code. Ensures every TODO is backed by a GitHub issue link and written as a doc comment in the host language's convention.
---

# TODO Comments

## Steps

1. Create a GitHub issue for the work first
2. Write the TODO as a doc comment (per the `single-line-code-comments` policy) with the issue URL on the next line

## Why

A TODO without a tracked issue is almost always a TODO forever — nobody greps through source to find them. Linking to an issue puts the context (why it matters, priority, owner) somewhere searchable and actionable.

## Examples

TypeScript / JavaScript:
```ts
/**
 * TODO: Implement caching layer
 * https://github.com/user/repo/issues/123
 */
```

Python:
```python
def fetch():
    """
    TODO: Add retries with backoff.
    https://github.com/user/repo/issues/123
    """
```

Rust:
```rust
/// TODO: Replace with async impl once tokio 2.0 lands.
/// https://github.com/user/repo/issues/123
fn fetch() { }
```

For other languages, use the idiomatic doc-comment form.
