{ lib, config, ... }:
lib.mkIf config.features.cli.eza.enable {
  programs.eza = {
    enable = true;
    icons = "auto";
  };
}
