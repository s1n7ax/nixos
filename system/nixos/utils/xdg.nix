{
  config,
  lib,
  pkgs,
  ...
}:

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
    # Pin ScreenCast/Screenshot to the hyprland backend; otherwise the request
    # can resolve to the KDE backend, which Firefox can't use ("Needs permission
    # to screen share"). gtk stays the default for file pickers etc.
    config.common = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
    };
  };
}
