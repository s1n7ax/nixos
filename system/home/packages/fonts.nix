{ pkgs, ... }:
{
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {

      emoji = [ "Noto Color Emoji" ];
      monospace = [
        "Noto Sans Mono"
        "CaskaydiaCove Nerd Font Mono"
      ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];

    };
  };

  home.packages = with pkgs; [
    noto-fonts
    noto-fonts-extra
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    (nerdfonts.override {
      fonts = [
        "FiraCode"
        "JetBrainsMono"
        "CascadiaCode"
        "CodeNewRoman"
      ];
    })
    maple-mono-NF
  ];
}
