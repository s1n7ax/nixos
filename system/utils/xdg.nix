{ pkgs, ... }:
{
  # flatpak needs xdg.portal.enable = true
  xdg.portal = {
    enable = true;
    configPackages = with pkgs; [
      xdg-desktop-portal
      kdePackages.xdg-desktop-portal-kde
    ];
  };
}
