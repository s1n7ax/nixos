---
name: logging
description: Use whenever the user asks to add logs, print messages, emit debug output, or trace execution — and when writing new code that should emit logs. Ensures the project's existing logger is used instead of raw stdout/stderr APIs.
---

# Logging

## Rule

Before reaching for raw stdout APIs (`console.log`, `println!`, `print`, `fmt.Println`, etc.), check whether the project has a configured logger (e.g. `pino`, `winston`, `tracing`, `slog`, `logback`). If one exists, use it.

## What to log

- At the start of high-level user-facing APIs: an info-level log confirming invocation (with key params, minus secrets)
- On successful completion of those APIs: an info-level log
- Before throwing a known error: log the original cause so it is not erased by wrapping

## Why

Configured loggers route through the project's level filtering, formatting, redaction, and sinks (files, aggregators, structured output). Raw stdout bypasses all of that, so logs added via `console.log` either get lost, duplicated, or leak sensitive data in production.
