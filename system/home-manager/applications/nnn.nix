{ pkgs, lib, config, ... }:
lib.mkIf config.features.cli.nnn.enable {

  programs.nnn = {
    enable = true;
    package = pkgs.nnn.override { withNerdIcons = true; };
  };
}
