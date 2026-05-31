{ ... }:
{
  dconf.enable = false;

  imports = [
    ./options.nix
    ./neovim.nix
    ../common/home.nix
  ];
}
