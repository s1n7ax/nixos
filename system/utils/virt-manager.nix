{ config, lib, ... }:

with lib;

{
  virtualisation = mkIf config.features.development.virt-manager.enable {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };
}
