{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  hardware.cpu.amd.updateMicrocode = pkgs.stdenv.hostPlatform.isx86;
  services.hardware.openrgb.enable = mkIf config.features.hardware.openrgb.enable true;
}
