{
  config,
  lib,
  ...
}:
with lib;

{
  config = mkIf config.features.development.ai.enable {
    programs.claude-code = mkIf config.features.development.ai.claude.enable {
      enable = true;

      settings = {
        theme = "dark";
        permissions = {
          allow = [
            "Bash(npmp run lint)"
            "Bash(npmp run test:*)"
            "Bash(npmp run dev)"
          ];
          deny = [
            "Bash(curl:*)"
            "Read(./.env)"
            "Read(./.env.*)"
            "Read(./secrets/**)"
          ];
        };
        outputStyle = "markdown";
        alwaysThinkingEnabled = true;
        includeCoAuthoredBy = false;
        statusLine = {
          enable = true;
          left = [
            { type = "git-branch"; }
            { type = "git-status"; }
          ];
          right = [
            { type = "directory"; }
            {
              type = "clock";
              format = "%H:%M";
            }
          ];
        };
      };
    };
  };
}
