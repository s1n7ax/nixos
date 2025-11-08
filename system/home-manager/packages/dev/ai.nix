{
  config,
  lib,
  pkgs-unstable,
  ...
}:
with lib;

{
  config = mkIf config.features.development.ai.enable {
    programs.opencode = {
      enable = config.features.development.ai.claude.enable;
      enableMcpIntegration = true;
      settings = {

      };
      rules = ''
        # Git rules

        ## Commits

        - Always use conventional commits https://www.conventionalcommits.org/en/v1.0.0/#specification
        - Use git status or git diff to see what changed and add one or more commits based on the context. Ex:- If there are two types of changes, use two commits.

        # Coding

        ## Comments

        - Never add single line comments for code you are adding. Only add doc comments only if it's a direct highlevel API we are exposing.
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
