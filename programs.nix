{ config, pkgs, ... }:
{
  programs.dconf.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.kdeconnect.enable = true;
}
