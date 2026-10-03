{
  config,
  lib,
  ...
}:
let
  common = import ./common.nix { };
in
{
  config = lib.mkIf config.features.development.ai.opencode.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        permission = {
          bash = {
            "*" = "ask";
            "* -h" = "allow";
            "* --version" = "allow";
            "* --help" = "allow";

            ## git
            "git add*" = "allow";
            "git diff*" = "allow";
            "git push*" = "allow";
            "git status*" = "allow";
            "git branch*" = "allow";
            "git switch*" = "allow";
            "git stash*" = "allow";
            "git checkout*" = "allow";
            "git log*" = "allow";
            # "git*" = "ask";

            "find *" = "allow";
            "ls*" = "allow";
            "cd*" = "allow";
            "cat *" = "allow";
            "rm *" = "ask";

            "pnpm *" = "allow";
            "pnpm install *" = "ask";
          };
          webfetch = "ask";
          websearch = "ask";
          edit = "allow";
          read = {
            ".env*" = "deny";
            "secrets*" = "deny";
          };
        };
      };
      tui = {
        theme = "catppuccin";
        # Mirrors claude/keybindings.json. No effort keys: opencode can only
        # cycle model variants forward (variant_cycle, ctrl+t).
        keybinds = {
          messages_half_page_up = "ctrl+u";
          messages_half_page_down = "ctrl+d";
          model_list = "<leader>m,ctrl+n";
          "dialog.select.prev" = "up,ctrl+p,ctrl+e";
          session_new = "<leader>n,ctrl+l";
        };
      };
      context = common.rules;
    };
  };
}
