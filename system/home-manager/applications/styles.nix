{ settings, pkgs, ... }:
{
  gtk = {
    enable = true;
    iconTheme = {
      inherit (settings.icon) name package;
    };
    theme = {
      name = "Breeze-Dark";
      package = pkgs.libsForQt5.breeze-gtk;
    };

    cursorTheme = {
      inherit (settings.cursor) name package size;
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
  };

  qt = {
    style = {
      name = "Breeze-Dark";
      package = pkgs.libsForQt5.breeze-qt5;
    };
  };
}
