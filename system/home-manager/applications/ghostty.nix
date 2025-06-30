{ pkgs, config, ... }:
{
  home.file.".config/ghostty/config".text = ''
    font-family = ${config.settings.font.name}
    font-size = ${config.settings.font.size}
    theme = Bright Lights
    cursor-style = bar
    cursor-style-blink = false
    window-decoration = false
  '';

  home.packages = with pkgs; [
    ghostty
  ];
}
