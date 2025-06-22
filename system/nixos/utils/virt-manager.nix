{ config, lib, ... }:

with lib;

{
  virtualisation = mkIf config.features.virtualization.virt-manager.enable {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };
}
