{
  pkgs,
  lib,
  config,
  ...
}:
let
  neovim_session = pkgs.writeText "neovim.kitty-session" ''
    cd ~/.config/nvim
    launch --title "Neovim Config" nvim
  '';
  /**
    Attaches to the homelab's one tmux session, creating it only when it is
    missing, so closing the window detaches instead of killing what runs there.
    The kitten requests a tty only without a remote command, hence -t.
  */
  homelab_session = pkgs.writeText "homelab.kitty-session" ''
    launch --title "Homelab" kitty +kitten ssh -t homelab tmux new-session -A -s main
  '';
  homelab_nvim_session = pkgs.writeText "homelab-nvim.kitty-session" ''
    launch --title "Homelab Neovim" kitty +kitten ssh homelab "cd ~/Workspace/nixos && nvim"
  '';
  dev_session = pkgs.writeText "dev.kitty-session" ''
    launch --title "Dev VM" kitty +kitten ssh dev
  '';
  mac_session = pkgs.writeText "mac.kitty-session" ''
    launch --title "Mac" kitty +kitten ssh macbook
  '';
  nix_session = pkgs.writeText "nixos.kitty-session" ''
    cd ~/Workspace/nixos
    launch --title "Nixos" nvim
  '';
  /**
    Sends Ctrl+1..9 as CSI u while tmux is attached, which sets the in_tmux
    user var. kitty only sends CSI u to apps that ask for its keyboard
    protocol and tmux never asks, so Neovim inside tmux would not see these
    keys; tmux passes CSI u on to it. Elsewhere the keys keep their usual
    control bytes (Ctrl+3 is Esc, Ctrl+8 is Backspace).
  */
  ctrl_number_keys = lib.listToAttrs (
    map (n: {
      name = "--when-focus-on var:in_tmux ctrl+${toString n}";
      value = "send_text normal,application \\x1b[${toString (48 + n)};5u";
    }) (lib.range 1 9)
  );
in
lib.mkIf config.features.terminal.kitty.enable {
  programs.kitty = {
    enable = true;

    font = {
      name = config.settings.font.name;
      size = config.settings.font.size;
    };

    settings = {
      cursor_blink_interval = 0;
      clear_all_shortcuts = "no";
      cursor_trail = 0;
      cursor_trail_decay = "0 0.5";
      cursor_trail_start_threshold = 0;
      confirm_os_window_close = 0;
      clipboard_control = "write-clipboard write-primary";
    };

    themeFile = "Catppuccin-Mocha";

    shellIntegration.enableZshIntegration = config.settings.shell == "zsh";
    shellIntegration.enableFishIntegration = config.settings.shell == "fish";

    keybindings = {
      "ctrl+c" = "copy_or_interrupt";
      "alt+s>n" = "goto_session ${neovim_session}";
      "alt+s>t" = "goto_session ${homelab_session}";
      "alt+s>d" = "goto_session ${dev_session}";
      "alt+s>m" = "goto_session ${mac_session}";
      "alt+s>e" = "goto_session ${nix_session}";
    }
    // ctrl_number_keys;
  };
}
