{ config, lib, ... }:

with lib;

{
  virtualisation.virtualbox.host = mkIf config.features.virtualization.virtualbox.enable {
    enable = true;
    enableKvm = true;
    addNetworkInterface = false;
    enableHardening = true;
  };

  virtualisation.virtualbox.guest = mkIf config.features.virtualization.virtualbox.enable {
    enable = true;
  };
}
