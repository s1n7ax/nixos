{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./storage.nix
    ./gpg.nix
    ./options.nix
    ../../system/nixos/profile/server
  ];
}
