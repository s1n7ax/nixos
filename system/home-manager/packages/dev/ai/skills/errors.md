---
name: errors
description: Use when writing code that throws, raises, or creates errors/exceptions, when defining custom error types, or when reviewing error-handling code. Covers which type to throw, expected-vs-unexpected classification, and doc-comment conventions.
---

# Errors

## Rules

- Never throw the language's generic error type (`Error` in JS/TS, `Exception` in Java, etc.). Always throw a named custom type.
- Custom error types extend the language's base error class.
- Distinguish **expected** errors (normal flow: validation, not-found, auth) from **unexpected** errors (network, DB, infra). Give each an appropriate named type so callers can react differently.
- Name types after the failure mode, not the layer: `ValidationError`, `NotFoundError`, `AuthenticationError` — not `ServiceError` or `UtilError`.
- Before throwing a wrapped or translated error, log the original cause, otherwise it disappears up the stack.
- Document thrown errors in doc comments using the language's convention (`@throws` for JSDoc / Javadoc / KDoc).
- When a function's error behavior changes, update its doc comment to match.

## Why

Generic error types force callers to string-match messages to handle different failure modes. Named types let callers pattern-match on type, make the failure surface visible in type-checkers and IDEs, and prevent "one catch swallows everything" anti-patterns.
