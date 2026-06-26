{ ... }:
{
  imports = [
    ./options.nix
    ../common/home.nix
    ../../system/home-manager/profile/server
    ../../system/home-manager/self-hosted-services
  ];
}
