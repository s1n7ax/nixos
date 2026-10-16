{ config, lib, ... }:

with lib;

{
  programs.kdeconnect.enable = mkIf config.features.desktop.kdeconnect.enable true;
  programs.dconf.enable = mkIf config.features.desktop.dconf.enable true;

  programs.gnupg.agent = mkIf config.features.security.gpg.enable {
    enable = true;
  };

  programs.hyprland = mkIf config.features.desktop.hyprland.enable {
    enable = true;
    xwayland.enable = true;
    # The session runs the Hyprland home-manager configures. Its aquamarine
    # (>= 0.15.1, hyprwm/aquamarine#378) adds the keyboard and mouse back
    # right after a wake; 0.11.0 waited for the first key, and lost it.
    package = config.settings.wm.package;
    portalPackage = config.settings.wm.portalPackage;
  };
}
