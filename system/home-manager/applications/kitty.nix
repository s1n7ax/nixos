{ pkgs, config, ... }:
let
  neovim_session = pkgs.writeText "neovim.kitty-session" ''
    cd ~/.config/nvim
    launch --title "Neovim Config" nvim
  '';
  homelab_session = pkgs.writeText "homelab.kitty-session" ''
    launch --title "Homelab" kitty +kitten ssh s1n7ax@192.168.1.110
  '';
  nix_session = pkgs.writeText "homelab.kitty-session" ''
    cd ~/Workspace/nixos
    launch --title "Nixos" nvim
  '';
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = config.settings.font.name;
      size = config.settings.font.size;
    };

    settings = {
      "ctrl+c" = "copy_or_interrupt";
      cursor_blink_interval = 0;
      clear_all_shortcuts = "no";
      cursor_trail = 0;
      cursor_trail_decay = "0 0.5";
      cursor_trail_start_threshold = 0;
      confirm_os_window_close = 0;
    };

    themeFile = "Catppuccin-Mocha";

    shellIntegration.enableZshIntegration = config.settings.shell == "zsh";
    shellIntegration.enableFishIntegration = config.settings.shell == "fish";

    keybindings = {
      "alt+s>n" = "goto_session ${neovim_session}";
      "alt+s>t" = "goto_session ${homelab_session}";
      "alt+s>e" = "goto_session ${nix_session}";
    };
  };
}
