{ config, pkgs, ...}:

{
  services.openssh.enable = true;
  services.flatpak.enable = true;
  services.udisks2.enable = true;
}
