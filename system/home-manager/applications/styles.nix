{
  lib,
  config,
  pkgs,
  ...
}:
lib.mkIf config.features.desktop.styles.enable {
  gtk = {
    enable = true;
    iconTheme = {
      inherit (config.settings.icon) name package;
    };
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };

    gtk4.theme = config.gtk.theme;

    cursorTheme = {
      inherit (config.settings.cursor) name package size;
    };
    gtk3.extraConfig = {
      gtk-button-images = 0;
      gtk-menu-images = 0;
      gtk-enable-event-sounds = 1;
      gtk-enable-input-feedback-sounds = 0;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintfull";
      gtk-xft-rgba = "rgb";
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # GSettings schemas live under share/gsettings-schemas/<name>, which nothing
  # adds to XDG_DATA_DIRS. Apps launched through a wrapGAppsHook'd launcher
  # (rofi) inherit them from its wrapper, but ones exec'd straight from Hyprland
  # cannot resolve org.gnome.desktop.interface and lose the UI font — Firefox
  # renders its tab labels blank. Prepend them session-wide instead.
  home.sessionVariables.XDG_DATA_DIRS =
    let
      schemas = pkg: "${pkg}/share/gsettings-schemas/${pkg.name}";
    in
    "${schemas pkgs.gsettings-desktop-schemas}:${schemas pkgs.gtk3}:$XDG_DATA_DIRS";

  qt = {
    style = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze;
    };
  };
}
