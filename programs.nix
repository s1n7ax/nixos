{ config, pkgs, ... }:
{
  programs.dconf.enable = true;

  programs.gnupg.agent = {
    enable = true;
  };

  programs.hyprland = {
    enable = true;
    enableNvidiaPatches = true;
    xwayland.enable = true;
  };

  programs.kdeconnect.enable = true;
}
