{
  mcpServers = {
    svelte = {
      command = "npx";
      args = [
        "-y"
        "@sveltejs/mcp"
      ];
    };
    nextjs = {
      command = "npx";
      args = [
        "-y"
        "next-devtools-mcp@latest"
      ];
    };
    tailwindcss = {
      command = "npx";
      args = [
        "-y"
        "tailwindcss-mcp-server"
      ];
    };
    chakra-ui = {
      command = "npx";
      args = [
        "-y"
        "@chakra-ui/react-mcp"
      ];
    };
    context7 = {
      command = "npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
      ];
    };
  };

  rules = ''
    # AGENTS.md

    ## MCP

    - Use Context7 MCP when we don't have a dedicated MCP but I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.


    # Working relationship

    - No sycophancy.
    - Be direct, matter-of-fact, and concise.
    - Be critical; challenge my reasoning.
    - Don't include timeline estimates in plans.
    - Minimal explanations. Senior engineer context assumed.
  '';

  skills = {
    github-prs = ''
      ---
      name: github-prs
      description: Use whenever the user asks to create, open, push, or submit a PR / pull request, or mentions merging changes via GitHub. Covers branch strategy, PR title/description conventions, and triaging Copilot review-bot comments.
      ---

      # GitHub Pull Requests

      ## Steps

      - Never commit directly to the default branch; create a dedicated branch per PR
      - Commit the changes on the PR branch
      - Push the branch
      - Open the PR from that branch

      ## PR Title

      Use conventional-commit syntax (same convention as git commits):

      `<type>[scope]: <description>`

      ## PR Description

      Summarize the changes in 1–3 bullet points.

      ## Review Bot Comments

      Projects may have Copilot or similar review bots enabled. These bots mix valid findings with low-signal nits, so filter before surfacing anything to the user.

      After creating the PR:

      1. Check for review comments with `gh pr view --json reviews`
      2. If none yet, tell the user the bot may still be processing and they can ask you to recheck later
      3. When comments exist:
         - Read each one carefully
         - Challenge every suggestion — decide whether it is correct and applicable before presenting it
         - Discard false positives and pure stylistic nits with no real impact
         - Present only valid comments as a numbered list with file, line, and the suggestion
         - Ask the user which ones to fix
    '';

    errors = ''
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
    '';

    logging = ''
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
    '';

    single-line-code-comments = ''
      ---
      name: single-line-code-comments
      description: Use whenever adding, editing, or asked to write comments in code. This project forbids inline single-line comments (`//`, `#`, `--`) — only doc comments (`/** */`, docstrings, `///`) are permitted.
      ---

      # Comment Policy

      ## Rule

      Do not add single-line comments (`//`, `#`, `--`, etc.). Only doc comments (`/** */`, `"""..."""`, `///`, or the language equivalent) are allowed.

      ## Why

      Single-line comments tend to accumulate as stale narration of what the next line does ("increment counter", "loop over items"). They decay quickly as code changes and rarely carry information the code itself doesn't already express. Doc comments, by contrast, describe contracts and intent at API boundaries — callers depend on them, so they stay maintained.

      ## How to apply

      - If logic genuinely isn't self-evident, extract a well-named function or variable instead of commenting.
      - If context is required (a non-obvious workaround, a link to an issue), put it in the doc comment on the enclosing function or type.
      - `TODO:` markers follow the `todo-comments` skill and use doc-comment form there as well.
    '';

    override-hm-module = ''
      ---
      name: override-hm-module
      description: Override a home-manager module with a specific commit. Use when a module has bugs or missing features and you need a newer version without updating all flakes.
      ---

      # Override Home-Manager Module

      ## Steps

      1. Add pinned input in `flake.nix`:
      ```nix
      home-manager-<name> = {
        url = "github:nix-community/home-manager/<COMMIT_HASH>";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      ```

      2. In the module file:
      ```nix
      {
        inputs,
        ...
      }:
      {
        imports = [
          "''${inputs.home-manager-<name>}/modules/programs/<module>.nix"
        ];

        disabledModules = [
          "programs/<module>.nix"
        ];

        # ... rest of config
      }
      ```
    '';

    todo-comments = ''
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
    '';

    git-commits = ''
      ---
      name: git-commits
      description: Use whenever the user asks to commit, stage commits, write a commit message, or split work into multiple commits. Enforces conventional-commit syntax and the "commit what's there, do not edit code" rule.
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
    '';

    home-manager-options = ''
      ---
      name: home-manager-options
      description: Use when looking up available home-manager options, their types, defaults, or descriptions — e.g. "what options does programs.X expose", "how do I configure X in home-manager", or when unsure whether an option exists.
      ---

      # Home-Manager Options

      Run:

      ```bash
      man home-configuration.nix | grep -C10 'programs.rclone'
      ```

      Replace the pattern with the option path of interest. Adjust `-C10` up or down to widen or narrow the surrounding context.

      ## Why

      The `home-configuration.nix` manpage is the authoritative, locally-installed source — faster and more accurate than a web search, and it matches the exact home-manager version on this system rather than whatever version the internet is talking about.
    '';

    nvim-headless-test = ''
      ---
      name: nvim-headless-test
      description: Use when modifying Neovim Lua configuration that affects window management, autocmds, buffer behavior, statusline, or any UI-observable behavior — and when debugging why an autocmd or window event fires unexpectedly. Runs the real config in a headless nvim so assertions reflect actual behavior.
      ---

      # Neovim Headless Testing

      ## How to run

      ```bash
      nvim --headless -u init.lua -c "luafile test_file.lua" 2>&1
      ```

      ## Writing a test script

      1. Set a known screen size: `vim.o.columns = 160; vim.o.lines = 40`
      2. Create windows/buffers programmatically via `nvim_create_buf`, `nvim_open_win`
      3. Trigger autocmds by setting filetypes: `vim.bo[buf].filetype = 'name'`
      4. Switch focus with `vim.api.nvim_set_current_win(win)`
      5. After focus changes, call `vim.wait(200, function() return false end)` so `vim.schedule` callbacks execute
      6. Emit state with `io.write()` / `io.flush()` to inspect it
      7. Exit with `vim.cmd('qa!')`

      ## Gotchas

      - Do **not** call `vim.cmd('doautocmd WinEnter')` after `nvim_set_current_win` — the API call already fires `WinEnter`. Doubling it causes stale-state bugs that look like race conditions.
      - Delete the test script once debugging is done; leaving scratch `.lua` files around clutters the config.
    '';

  };
}
