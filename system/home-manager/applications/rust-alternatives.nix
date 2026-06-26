{ pkgs, lib, config, ... }:
lib.mkIf config.features.cli.rustAlternatives.enable {
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
