{
  config,
  lib,
  ...
}:
let
  common = import ./common.nix;
in
{
  config = lib.mkIf config.features.development.ai.claude.enable {
    programs.claude-code = {
      enable = true;
      memory.text = common.rules;
      settings = {
        skils = common.skills;
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
