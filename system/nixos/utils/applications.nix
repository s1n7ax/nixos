{ config, lib, ... }:

with lib;

{
  programs.kdeconnect.enable = mkIf config.features.desktop.kdeconnect.enable true;
  programs.dconf.enable = mkIf config.features.desktop.dconf.enable true;

  programs.gnupg.agent = mkIf config.features.security.gpg.enable {
    enable = true;
  };

  programs.gpu-screen-recorder.enable = mkIf config.features.productivity.video-production.screen-capture.enable true;

  programs.hyprland = mkIf config.features.desktop.hyprland.enable {
    enable = true;
    xwayland.enable = true;
  };
}
