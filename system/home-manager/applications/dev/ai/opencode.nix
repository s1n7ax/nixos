{
  pkgs,
  config,
  lib,
  ...
}:
let
  commonRules = builtins.readFile ./AGENTS.md;
  welcome = import ./welcome {
    inherit pkgs;
    inherit (config.home) username;
  };
in
{
  config = lib.mkIf config.features.development.ai.opencode.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        /**
          Nix pins the version, so the "update now?" dialog that covers the
          home screen on every new release could never succeed anyway.
        */
        autoupdate = false;
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
        plugin = [ welcome.opencodePlugin ];
        keybinds = {
          messages_half_page_up = "ctrl+u";
          messages_half_page_down = "ctrl+d";
        };
      };
      context = commonRules;
    };
  };
}
