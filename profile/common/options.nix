{ pkgs, ... }:
{
  settings = {
    username = "s1n7ax";
    shell = "fish";
    wm = {
      name = "hyprland";
      package = pkgs.hyprland;
    };
    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 32;
    };
    font = {
      name = "Iosevka Nerd Font Mono";
      size = 18;
    };
    icon = {
      name = "Tela-circle-dark";
      package = pkgs.tela-circle-icon-theme;
    };
    terminal = "kitty";
  };
}
