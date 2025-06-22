{ config, ... }:
{
  home.pointerCursor = {
    inherit (config.settings.cursor) name package size;
    gtk.enable = true;
    x11.enable = true;
    x11.defaultCursor = "Bibata-Modern-Ice";
  };
}
