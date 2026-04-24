{
  config,
  lib,
  inputs,
  ...
}:
let
  common = import ./common.nix;
in
{
  # TODO: Remove this pin once upstream fixes skill file structure bug
  # https://github.com/s1n7ax/nixos/issues/7
  imports = [
    "${inputs.home-manager-claude}/modules/programs/claude-code.nix"
  ];

  disabledModules = [
    "programs/claude-code.nix"
  ];

  config = lib.mkIf config.features.development.ai.claude.enable {
    programs.claude-code = {
      enable = true;
      memory.text = common.rules;
      skills = common.skills;
      settings = {
        enabledPlugins = {
          "frontend-design@claude-plugins-official" = true;
          "feature-dev@claude-plugins-official" = true;
          "code-review@claude-plugins-official" = true;
          "code-simplifier@claude-plugins-official" = true;
          "skill-creator@claude-plugins-official" = true;
        };
        model = "claude-opus-4-7";
        attribution = {
          commit = "";
          pr = "";
        };
        alwaysThinkingEnabled = true;
        terminalProgressBarEnabled = true;
        permissions = {
          allow = [
            "Bash(* --help *)"
            "Bash(* --version)"
            "Bash(cat *)"
            "Bash(ct *)"
            "Bash(find *)"
            "Bash(gh pr diff*)"
            "Bash(gh pr list*)"
            "Bash(gh pr view*)"
            "Bash(git add *)"
            "Bash(git diff *)"
            "Bash(git push *)"
            "Bash(ls *)"
            "Bash(npx tsc *)"
            "Bash(pnpm *)"
            "Bash(pnpm run *)"
          ];
          ask = [
            "Bash(git commit *)"
            "Bash(pnpm install*)"
            "Bash(rm*)"
          ];
          deny = [
            "Read(**/.env)"
            "Read(**/.env.*)"
            "Read(.env)"
            "Read(.env.*)"
            "Read(**/secrets/**)"
            "Bash(cat *.env*)"
            "Bash(cat *secrets*)"
            "Bash(*.env*)"
            "Bash(*secrets/*)"
          ];
        };
        env = {
          CLAUDE_CODE_ENABLE_TELEMETRY = "0";
        };
        theme = "dark";
        mcpServers = common.mcpServers;
      };
    };
  };
}
