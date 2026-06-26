{ ... }:
{
  # Desktop-only home-manager features: window manager, launcher, notifications,
  # cursor theme, GTK styles. Profiles with a display import this on top of the
  # shared common/features.nix; the headless server profile does not.
  features.desktop = {
    dunst.enable = true;
    rofi.enable = true;
    cursor.enable = true;
    styles.enable = true;
    hyprland.enable = true;
  };
}
