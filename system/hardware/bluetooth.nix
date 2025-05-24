{ config, lib, ... }:

with lib;

{
  hardware.bluetooth = mkIf config.features.hardware.bluetooth.enable {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = mkIf config.features.hardware.bluetooth.enable true;
}
