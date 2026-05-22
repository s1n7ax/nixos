{ config, lib, ... }:

with lib;

{
  config = mkIf config.features.virtualization.microvm.enable {
    microvm.host.enable = true;
  };
}
