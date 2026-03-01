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

    ## 'to mem' Instruction

    - When the user says 'to mem' in a prompt, update the AGENTS.md file with the provided information

    # Working relationship

    - No sycophancy.
    - Be direct, matter-of-fact, and concise.
    - Be critical; challenge my reasoning.
    - Don't include timeline estimates in plans.
    - Minimal explanations. Senior engineer context assumed.
  '';

  skills = {
    logging = ''
      ---
      name: logging
      description: How to add logs, print messages in a project
      ---

      # Logging

      - Before using standard output APIs, we should look if there is a logging API available in the project. 
        For example, in JavaScript projects, we can use `console.log` or `console.error` to log messages but it's 
        hightly likely that the project has `pino` or some other logger configured. We should always use that over standard output APIs of the language
    '';

    single-line-code-comments = ''
      ---
      name: single-line-code-comments
      description: Skills related to adding single line code comments
      ---

      ## What NOT to Do

      - Never add single line comments. Only doc comments are allowed
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
      description: Add TODO comments to code with linked GitHub issues
      ---

      # TODO Comments

      ## Steps

      1. Create a GitHub issue first
      2. Add the issue URL on the next line

      ## Examples

      TypeScript/JavaScript:
      ```ts
      /**
       * TODO: Implement caching layer
       * https://github.com/user/repo/issues/123
       */
      ```
    '';

    git-commits = ''
      ---
      name: git-commits
      description: Skills related to git creating git commits
      ---

      # Git Commit Skill

      ## Commits

      - If changes are not related, break them down into smaller commits

      ## Git Commit Message Skill

      1. Conventional commit messages

      Syntax:

      ```
      <type>[scope]: <description>

      [optional body]

      [optional footer(s)]
      ```

      Types:

      - fix: fixes an issue
      - feat: introduces a new feature
      - chore: housekeeping changes (linting, formatting, etc.)
      - ci: changes to the CI configuration files and scripts
      - docs: changes to the documentation
      - style: changes the appearance of the application
      - refactor: changing existing behavior or functionality
      - test: adding missing tests or correcting existing tests

      ---

      Scope:

      Scopes are most of the time project specific

      For example:

      In a neovim configuration

      - keymap: adds/removes keyboard shortcuts
      - autocmd: adds/removes autocommands

      In a react project

      - router: changes the routing system

      However, we can have generic scopes as well

      - core: changes to the core functionality
      - ui: changes to the user interface
      - ux: changes to the user experience
      - api: changes to the API
      - auth: changes to the authentication system

      ### Breaking changes

      BREAKING CHANGE: a commit that has a footer BREAKING CHANGE:, or appends a ! after the type/scope, introduces a breaking API change

      Examples:

      - feat!: adds a new feature but breaks compatibility
      - fix!: fixes a bug but breaks compatibility
      - refactor!: remove a code change that neither fixes a bug nor adds a feature that breaks compatibility

      ---

      ## What NOT to Do

      - When user asks to commit the changes, never make any change to the codebase. Just commit the changes as it is.
    '';
  };
}
