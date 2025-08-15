{ config, ... }:
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      theme = "catppuccin-mocha";
      font-family = config.settings.font.name;
      font-size = config.settings.font.size;
      cursor-style = "block";
      cursor-style-blink = false;
      window-decoration = false;
    };
  };
}
