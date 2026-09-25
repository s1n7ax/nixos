---
name: error-handling
description: Use when writing code that throws, raises, or creates errors/exceptions, when defining custom error types, or when reviewing error-handling code. Covers which type to throw, expected-vs-unexpected classification, and doc-comment conventions.
---

# Errors

## Rules

- Never throw the language's generic error type (`Error` in JS/TS, `Exception` in Java, etc.). Always throw a named custom type.
- Custom error types extend the language's base error class.
- Distinguish **expected** errors (normal flow: validation, not-found, auth) from **unexpected** errors (network, DB, infra). Give each an appropriate named type so callers can react differently.
- Name types after the failure mode, not the layer: `ValidationError`, `NotFoundError`, `AuthenticationError` — not `ServiceError` or `UtilError`.
- Log before throwing an error, and log the error when you catch it; pick the log level that fits the situation. Use the project's configured logger rather than raw stdout.
- Document thrown errors in doc comments using the language's convention (`@throws` for JSDoc / Javadoc / KDoc).
- When a function's error behavior changes, update its doc comment to match.

## Why

Generic error types force callers to string-match messages to handle different failure modes. Named types let callers pattern-match on type, make the failure surface visible in type-checkers and IDEs, and prevent "one catch swallows everything" anti-patterns.

## Languages without exceptions

In Go, Rust, and similar languages, errors are values, not thrown. The same principles apply: define named error types (Go: types implementing `error`; Rust: enums with `thiserror` or similar) rather than returning bare `errors.New("...")` / `anyhow!("...")` everywhere, and document the error variants a function can return.
