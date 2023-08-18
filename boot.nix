{ config, pkgs, ... }:
{
  boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];
  boot.supportedFilesystems = [ "ntfs" ];
}
