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
        attribution = {
          commit = "";
          pr = "";
        };
        alwaysThinkingEnabled = true;
        terminalProgressBarEnabled = true;
        permissions = {
          allow = [
            "Bash(pnpm run *)"
            "Bash(pnpm *)"
            "Bash(npx tsc *)"

            "Bash(git add *)"
            "Bash(git diff *)"
            "Bash(git push *)"

            "Bash(* --version)"
            "Bash(* --help *)"

            "Bash (find *)"
            "Bash (ls *)"
            "Bash (ct *)"
            "Bash (cat *)"
          ];
          ask = [
            "Bash(git commit *)"
            "Bash(pnpm install*)"
            "Bash(rm*)"
          ];
          deny = [
            "Read(./.env)"
            "Read(./.env.*)"
            "Read(./secrets/**)"
          ];
        };
        env = {
          CLAUDE_CODE_ENABLE_TELEMETRY = "0";
          OTEL_METRICS_EXPORTER = "otlp";
        };
        theme = "dark";
      };
    };
  };
}
