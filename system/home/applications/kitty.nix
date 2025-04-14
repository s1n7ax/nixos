{ settings, ... }:
{
  programs.kitty = {
    enable = true;

    font = {
      name = settings.font.name;
      size = settings.font.size;
    };
    settings = {
      "ctrl+c" = "copy_or_interrupt";
      "cursor_blink_interval" = 0;
      "clear_all_shortcuts" = "no";

    };
    themeFile = "Catppuccin-Mocha";

    shellIntegration.enableZshIntegration = settings.shell == "zsh";
    shellIntegration.enableFishIntegration = settings.shell == "fish";
  };
}
