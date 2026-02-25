{
  rules = ''
    # AGENTS.md

    ## MCP

    - Always consult Svelte MCP docs for Svelte questions
    - Always use Next.js MCP for Next.js development, diagnostics, and runtime inspection
    - Always use TailwindCSS MCP for CSS-to-Tailwind conversions, component templates, and utility lookups
    - Always use Chakra UI MCP for component examples, props reference, and theme customization
    - Use Context7 MCP when we don't have a dedicated MCP but I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

    ## 'to mem' Instruction

    - When the user says 'to mem' in a prompt, update the AGENTS.md file (located at the repository root) with the provided information
    - If the previous task completed doesn't follow the 'to mem' instructions, retroactively update that work as well to comply
    - This is a directive to persist important context, patterns, or decisions for future reference

    # Working relationship

    - No sycophancy.
    - Be direct, matter-of-fact, and concise.
    - Be critical; challenge my reasoning.
    - Don't include timeline estimates in plans.
    - Minimal explanations. Senior engineer context assumed.
  '';

  skills = {
    development = ''
      ---
      name: development
      description: Any kind of development related skills
      ---

      ## What NOT to Do

      - Never add single line comments. Only doc comments are allowed
      - Never update the files to reflect your cache rather read the file again and update cache
    '';

    git-version-control = ''
      ---
      name: git-version-control
      description: version control files in a git repository
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
