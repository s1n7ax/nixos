---
name: git-commits
description: Use whenever you git commit, write a commit message, or split work into multiple commits. Enforces conventional-commit syntax and the "commit what's there, do not edit code" rule.
---

# Git Commits

## Critical rule

When the user asks to commit, **do not modify the codebase**. Commit what is already staged or present. Any "while we're at it" fix must be a separate, explicit request.

**Why:** the user has already decided what belongs in this commit. Silent edits mix reviewable change with unrelated noise and cannot be undone from the commit alone.

## Splitting commits

If staged changes span unrelated concerns, split them into smaller commits that each stand on their own.

## Message format

Conventional-commit syntax:

```
<type>[scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `fix`: fixes an issue
- `feat`: introduces a new feature
- `chore`: housekeeping (deps, tooling, formatting-only)
- `ci`: CI config / pipeline changes
- `docs`: documentation
- `style`: visual/UI appearance only
- `refactor`: behavior-preserving restructure
- `test`: tests added or corrected

### Scope

Scope is project-specific. Pick it from the area actually touched in the diff; do not invent a new scope casually.

Illustrative examples (not exhaustive):

- Neovim config: `keymap`, `autocmd`, `plugin`
- React project: `router`, `api`
- Nix / home-manager: `hm`, `flake`, `module`

Generic fallbacks: `core`, `ui`, `ux`, `api`, `auth`.

### Breaking changes

Either append `!` after the type/scope, or include a `BREAKING CHANGE:` footer. Both together is fine.

Examples:

- `feat!: drop support for Node 18`
- `refactor(api)!: rename /users to /accounts`
