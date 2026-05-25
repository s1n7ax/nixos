{ config, lib, ... }:

with lib;

{
  config = mkIf config.features.virtualization.virt-manager.enable {
    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };

    programs.virt-manager.enable = true;
  };
}
