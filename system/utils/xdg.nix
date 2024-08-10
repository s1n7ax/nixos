{ pkgs, ... }:
{
  # flatpak needs xdg.portal.enable = true
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    configPackages = [ pkgs.hyprland ];
  };
}
