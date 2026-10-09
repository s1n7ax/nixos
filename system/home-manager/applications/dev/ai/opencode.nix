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
          /**
            Editor cursor movement mirrors fish.nix: ctrl+n/ctrl+e move by
            word, ctrl+o jumps to line end. ctrl+a line start and ctrl+w
            kill-word are already OpenCode defaults. A configured list
            replaces the defaults, so those are repeated.
          */
          input_word_backward = "alt+b,alt+left,ctrl+left,ctrl+n";
          input_word_forward = "alt+f,alt+right,ctrl+right,ctrl+e";
          input_line_end = "ctrl+o";
          # Model select is alt+m in every agent (Pi, Claude); <leader>m is
          # kept because a configured list replaces the default.
          model_list = "alt+m,<leader>m";
        };
      };
      context = commonRules;
    };
  };
}
