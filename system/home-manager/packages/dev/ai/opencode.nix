{
  config,
  lib,
  ...
}:
let
  common = import ./common.nix;
in
{
  config = lib.mkIf config.features.development.ai.opencode.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        model = "anthropic/claude-sonnet-4-5";
        permission = {
          bash = {
            "*" = "ask";
            "* -h" = "allow";
            "* --version" = "allow";
            "* --help" = "allow";

            "git diff *" = "allow";
            "git push *" = "allow";
            "git status *" = "allow";
            "git branch *" = "allow";
            "git switch *" = "allow";

            "find *" = "allow";
            "ls *" = "allow";
            "ct *" = "allow";
            "cat *" = "allow";
            "rm *" = "ask";

            "pnpm *" = "allow";
            "pnpm install *" = "ask";
          };
          webfetch = "ask";
          websearch = "ask";
          edit = "ask";
          read = {
            ".env*" = "deny";
            "secrets*" = "deny";
          };
        };
        theme = "catppuccin";
        keybinds = {
          messages_half_page_up = "ctrl+u";
          messages_half_page_down = "ctrl+d";
        };
      };
      rules = common.rules;
    };
  };
}
