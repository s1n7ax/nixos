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
    zellij
    xh
    dua
  ];
}
