{ ... }:
{
  imports = [
    ./options.nix
    ./git.nix
    ../common/home.nix
    ../../system/home-manager/profile/server
    ../../system/home-manager/homelab
  ];
}
