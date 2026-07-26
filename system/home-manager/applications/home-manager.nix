{ lib, config, ... }:
lib.mkIf config.features.core.enable {
  programs.home-manager.enable = true;
}
