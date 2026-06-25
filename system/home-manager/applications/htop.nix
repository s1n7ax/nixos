{ lib, config, ... }:
lib.mkIf config.features.cli.htop.enable {
  programs.htop = {
    enable = true;
  };
}
