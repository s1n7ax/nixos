{ config, lib, ... }:

with lib;

{
  services.fwupd.enable = mkIf config.features.services.enable true;
  services.flatpak.enable = mkIf config.features.services.enable true;
}
