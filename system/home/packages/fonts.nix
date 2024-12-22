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
    # use nerd.fonts.<font_name> where font_name is any one of the fonts name from
    # https://www.nerdfonts.com/font-downloads
    nerd-fonts.fira-code
    maple-mono-NF
  ];
}
