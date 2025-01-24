{ settings, pkgs, ... }:
{
  programs.kitty = {
    enable = true;

    font = {
      name = settings.font.name;
      size = settings.font.size;
      package = pkgs.maple-mono-NF;
    };
    settings = {
      "ctrl+c" = "copy_or_interrupt";
      "cursor_blink_interval" = 0;
    };
    themeFile = "Catppuccin-Mocha";
    shellIntegration.enableZshIntegration = true;
  };
}
