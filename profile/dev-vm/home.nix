{ ... }:
{
  dconf.enable = false;

  imports = [
    ./options.nix
    # dev-vm has a display, so it opts into the desktop feature set.
    ../desktop/features.nix
    ../common/home.nix
  ];
}
