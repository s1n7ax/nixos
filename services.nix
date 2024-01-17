{ config, pkgs, ... }:

{
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  services.udisks2.enable = true;
  services.vnstat.enable = true;
  services.openssh = {
    enable = true;
    allowSFTP = true;
  };
}
