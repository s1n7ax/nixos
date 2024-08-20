{ pkgs, ... }:

{
  home.file = {
    ".config/nushell/modules".source = ./modules;
    ".config/nushell/scripts".source = pkgs.fetchgit {
      url = "https://github.com/nushell/nu_scripts.git";
      rev = "5ed3a961af0ea3dce24c36eae84580b4ec53fe35";
      sha256 = "eq6Drz7mSjB6GV5+uXJPYf2U27leaZQo5edfuzhTA0Q=";
      sparseCheckout = [
        "custom-completions/cargo"
        "custom-completions/git"
        "custom-completions/make"
        "custom-completions/nix"
        "custom-completions/npm"
        "custom-completions/pass"
        "custom-completions/yarn"
      ];
    };
  };

  programs.nushell = {
    enable = true;

    extraConfig = ''
      use ~/.config/nushell/modules/utils.nu

      use ~/.config/nushell/scripts/custom-completions/cargo/cargo-completions.nu *
      # use ~/.config/nushell/scripts/custom-completions/git/git-completions.nu *
      use ~/.config/nushell/scripts/custom-completions/make/make-completions.nu *
      use ~/.config/nushell/scripts/custom-completions/nix/nix-completions.nu *
      use ~/.config/nushell/scripts/custom-completions/npm/npm-completions.nu *
      use ~/.config/nushell/scripts/custom-completions/pass/pass-completions.nu *
      use ~/.config/nushell/scripts/custom-completions/yarn/yarn-completion.nu *

      $env.config = {
        show_banner: false

        keybindings: [
          {
            name: Completion_Next,
            modifier: CONTROL,
            keycode: Char_n,
            mode: emacs,
            event: {
              send: MenuDown
            }
          },
          {
            name: Completion_Prev,
            modifier: CONTROL,
            keycode: Char_e,
            mode: emacs,
            event: {
              send: MenuUp
            }
          },
          {
            name: Completion_Right,
            modifier: CONTROL,
            keycode: Char_i,
            mode: emacs,
            event: {
              send: MenuRight
            }
          },
          {
            name: Completion_Left,
            modifier: CONTROL,
            keycode: Char_m,
            mode: emacs,
            event: {
              send: MenuLeft
            }
          },
          {
            name: History_Hint_Complete,
            modifier: CONTROL,
            keycode: Char_s,
            mode: emacs,
            event: {
              send: HistoryHintComplete
            }
          },
          {
            name: Word_Complete,
            modifier: CONTROL,
            keycode: Char_t,
            mode: emacs,
            event: {
              send: HistoryHintWordComplete
            }
          },
          {
            name: Cursor_Left
            modifier: ALT
            keycode: Char_m
            mode: emacs
            event: {
              send: Left,
            }
          },
          {
            name: Cursor_Right
            modifier: ALT
            keycode: Char_i
            mode: emacs
            event: {
              send: Right,
            }
          },
          {
            name: Cursor_Down
            modifier: ALT
            keycode: Char_n
            mode: emacs
            event: {
              send: Down,
            }
          },
          {
            name: Cursor_Up
            modifier: ALT
            keycode: Char_e
            mode: emacs
            event: {
              send: Up,
            }
          },
          {
            name: Cursor_Next_Word
            modifier: ALT
            keycode: Char_w
            mode: emacs
            event: {
              edit: MoveBigWordRightStart,
            }
          },
          {
            name: Cursor_Prev_Word
            modifier: ALT
            keycode: Char_b
            mode: emacs
            event: {
              edit: MoveWordLeft
            }
          },
          {
            name: Delete_Word
            modifier: ALT
            keycode: Char_d
            mode: emacs
            event: [
              { edit: MoveWordLeft },
              { edit: CutWordRightToNext },
            ]
          }
        ]
      }
    '';

    environmentVariables = {
      WLR_NO_HARDWARE_CURSORS = "1"; # no cursor fix for wayland
      EDITOR = "nvim";
      TERM = "alacritty";
      PATH = ''
        (
          $env.PATH
          | split row (char esep)
          | prepend /home/s1n7ax/.cargo/bin
        )
      '';
    };

    shellAliases = {
      # common apps
      n = "nvim";
      f = "vifm";
      lg = "lazygit";
      ld = "lazydocker";
      yt = "yt-dlp";
      h = "Hyprland";

      # rust alternatives
      cat = "bat";
      ls = "eza -lg";
      l = "eza -lg";
      ll = "eza -lg";
      find = "fd";
      grep = "rg";

      # git
      g = "git";
      ga = "git add";
      gl = "git log --oneline";
      gla = "git log";
      gst = "git status";
      gp = "git pull";
      gP = "git push";
      gc = "git commit -m";
      gch = "git checkout";
      gb = "git branch";
      gd = "git diff";

      # devcontainer
      dc = "devcontainer --workspace-folder .";
      dcu = "devcontainer up --workspace-folder . --mount 'type=bind,source=/home/s1n7ax/.config/astronvim,target=/root/.config/astronvim'";
      dcr = "devcontainer up --workspace-folder . --mount 'type=bind,source=/home/s1n7ax/.config/astronvim,target=/root/.config/astronvim' --remove-existing-container";
      dcn = "devcontainer exec --workspace-folder . nvim";
      dcs = "devcontainer exec --workspace-folder . bash";

      # edit
      nh = "utils open-editor ~/.config/home-manager";
      nn = "utils open-editor ~/.config/nvim";
      na = "utils open-editor ~/.config/astronvim";
      no = "utils open-editor ~/Notes";
      np = "utils open-editor (project-menu)";

      # lazygit
      lh = "utils run-command-at 'lazygit' ~/.config/home-manager";
      ln = "utils run-command-at 'lazygit' ~/.config/nvim";
      la = "utils run-command-at 'lazygit' ~/.config/astronvim";
      lo = "utils run-command-at 'lazygit' ~/Notes";
      lp = "utils run-command-at 'lazygit' (project-menu)";

      # locations
      cdw = "cd ~/Workspace";
      cdn = "cd /etc/nixos";
    };
  };
}
