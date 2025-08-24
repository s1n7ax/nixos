{ config, lib, ... }:

with lib;

{
  virtualisation.waydroid = mkIf config.features.virtualization.waydroid.enable {
    enable = true;
  };
}