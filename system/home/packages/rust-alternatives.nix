{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bat
    difftastic
    ripgrep
    eza
    fd
    sd
    ripgrep
    starship
    zellij
  ];
}
