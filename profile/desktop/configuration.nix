{ ... }:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ../common/gpg.nix
    ./options.nix
    ../../system/nixos/profile/desktop
  ];
}
