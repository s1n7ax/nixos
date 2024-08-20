{ pkgs, ... }:
{
  # flatpak needs xdg.portal.enable = true
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
}
