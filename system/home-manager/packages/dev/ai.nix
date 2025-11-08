{
  config,
  lib,
  pkgs-unstable,
  ...
}:
with lib;

{
  config = mkIf config.features.development.ai.enable {
    home.packages = mkIf config.features.development.ai.claude.enable [
      pkgs-unstable.claude-code
    ];

    xdg.configFile."claude/config.json" = mkIf config.features.development.ai.claude.enable {
      text = builtins.toJSON {
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
