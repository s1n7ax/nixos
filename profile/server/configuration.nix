{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./storage-hdd.nix
    ./gpg.nix
    ./options.nix
    ../../system/nixos/profile/server
  ];
}
