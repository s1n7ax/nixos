{ pkgs, ... }: {
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];
  boot.supportedFilesystems = [ "ntfs" ];
}
