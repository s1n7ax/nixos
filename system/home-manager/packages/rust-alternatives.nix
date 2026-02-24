{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bat
    difftastic
    ripgrep
    fd
    sd
    ripgrep
    starship
    xh
    dua
  ];
}
