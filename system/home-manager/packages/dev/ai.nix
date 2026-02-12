{
  config,
  lib,
  ...
}:
with lib;

{
  config = mkIf config.features.development.ai.enable {
    programs.mcp = {
      enable = true;
      servers = {
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
    };

    programs.opencode = {
      enable = config.features.development.ai.opencode.enable;
      enableMcpIntegration = true;
      settings = {
        model = "anthropic/claude-opus-4.6";
        permission = {
          webfetch = "ask";
          websearch = "ask";
        };
        theme = "catppuccin";
        keybinds = {
          messages_half_page_up = "ctrl+u";
          messages_half_page_down = "ctrl+d";
        };
      };
      rules = ''
        # Git rules

        ## Commits

        - Always use conventional commits https://www.conventionalcommits.org/en/v1.0.0/#specification
        - Use git status or git diff to see what changed and add one or more commits based on the context. Ex:- If there are two types of changes, use two commits.
        - Never ever commit/push without user's prompt to commit/push the changes
        - When user asks to commit the changes, never make any change to the codebase. Just commit the changes as it is.
        - Don’t add yourself as a co-author to git commits.

        # Coding

        ## MCP

        - Always consult Svelte MCP docs for Svelte questions
        - Always use Next.js MCP for Next.js development, diagnostics, and runtime inspection
        - Always use TailwindCSS MCP for CSS-to-Tailwind conversions, component templates, and utility lookups
        - Always use Chakra UI MCP for component examples, props reference, and theme customization
        - Use Context7 MCP when we don't have a dedicated MCP but I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

        ## Comments

        - Never add single line comments for code you are adding. Only add doc comments only if it's a direct highlevel API we are exposing.

        # Memory Management

        ## Cache

        - I most often update the files manually. So if your cache is out of date, update your cache.
        - Never ever update the file to refact the cache changes. Just update the cache with the latest file changes.

        ## 'to mem' Instruction

        - When the user says 'to mem' in a prompt, update the AGENTS.md file (located at the repository root) with the provided information
        - If the previous task completed doesn't follow the 'to mem' instructions, retroactively update that work as well to comply
        - This is a directive to persist important context, patterns, or decisions for future reference

        # Working relationship

        - No sycophancy.
        - Be direct, matter-of-fact, and concise.
        - Be critical; challenge my reasoning.
        - Don’t include timeline estimates in plans.
      '';
    };

    programs.claude-code = {
      enable = config.features.development.ai.claude.enable;
      settings = {
        includeCoAuthoredBy = false;
        permissions = {
          allow = [
            "Bash(git diff:*)"
            "Edit"
          ];
          ask = [
            "Bash(git push:*)"
          ];
          deny = [
            "Read(./.env)"
            "Read(./secrets/**)"
          ];
          disableBypassPermissionsMode = "disable";
        };
        model = "opus";
        statusLine = {
          command = "~/.claude/statusline.sh";
          padding = 0;
          type = "command";
        };
        theme = "dark";
      };
    };

    home.file.".claude/settings.json" = mkIf config.features.development.ai.claude.enable {
      text = builtins.toJSON {
        alwaysThinkingEnabled = true;
        statusLine = {
          type = "command";
          command = "~/.claude/statusline.sh";
          padding = 0;
        };
      };
    };

    home.file.".claude/statusline.sh" = mkIf config.features.development.ai.claude.enable {
      executable = true;
      text = ''
        #!/usr/bin/env bash

        # Read JSON input
        input=$(cat)

        # Extract data using jq
        CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')

        # Git branch and status
        if git rev-parse --git-dir > /dev/null 2>&1; then
          BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

          # Git status indicators
          if [[ -n $(git status -s 2>/dev/null) ]]; then
            STATUS="●"  # Modified
          else
            STATUS="✓"  # Clean
          fi

          GIT_INFO="\033[36m''${BRANCH}\033[0m \033[33m''${STATUS}\033[0m"
        else
          GIT_INFO=""
        fi

        # Directory (basename only)
        DIR_NAME=$(basename "$CURRENT_DIR")

        # Build status line
        if [[ -n "$GIT_INFO" ]]; then
          echo -e "''${GIT_INFO}  \033[35m''${DIR_NAME}\033[0m"
        else
          echo -e "\033[35m''${DIR_NAME}\033[0m"
        fi
      '';
    };
  };
}
