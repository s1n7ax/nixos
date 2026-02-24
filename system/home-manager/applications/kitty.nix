{ config, ... }:
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
  };
}
