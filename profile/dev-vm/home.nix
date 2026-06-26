{ ... }:
{
  dconf.enable = false;

  imports = [
    ./options.nix
    ../common/home.nix
  ];
}
