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
      "cursor_blink_interval" = 0;
      "clear_all_shortcuts" = "no";

    };
    themeFile = "Catppuccin-Mocha";

    shellIntegration.enableZshIntegration = config.settings.shell == "zsh";
    shellIntegration.enableFishIntegration = config.settings.shell == "fish";
  };
}
