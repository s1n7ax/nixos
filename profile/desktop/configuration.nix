{ ... }:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./gpg.nix
    ./options.nix
    ../../system/nixos/profile/desktop
  ];
}
