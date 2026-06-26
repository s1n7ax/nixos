{ lib, config, ... }:
lib.mkIf config.features.fonts.enable {
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      emoji = [ "Noto Color Emoji" ];
      monospace = [
        "Iosevka Nerd Font Mono"
        "Noto Sans Mono"
        "CaskaydiaCove Nerd Font Mono"
      ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];

    };
  };
}
