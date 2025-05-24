{ config, lib, ... }:

with lib;

{
  hardware.cpu.amd.updateMicrocode = true;
  services.hardware.openrgb.enable = mkIf config.features.hardware.openrgb.enable true;
}
