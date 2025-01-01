{ pkgs, settings, ... }:
{
  home.file.".config/ghostty/config".text = ''
    font-family = ${settings.font.name}
    font-size = ${settings.font.size}
    theme = catppuccin-frappe
    cursor-style = bar
    cursor-style-blink = false
    window-decoration = false
  '';

  home.packages = with pkgs; [
    ghostty
  ];
}
