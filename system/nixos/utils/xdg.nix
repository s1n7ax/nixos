{ config, lib, pkgs, ... }:

with lib;

{
  # flatpak needs xdg.portal.enable = true
  xdg.portal = mkIf config.features.desktop.xdg.enable {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
  };
}
