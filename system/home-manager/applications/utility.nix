{
  lib,
  config,
  ...
}:
{
  imports = [
    ./dunst.nix
    ./home-manager.nix
    ./vifm.nix
    ./yazi.nix
    ./rofi.nix
    ./xdg.nix
    ./zathura.nix
    ./neovim.nix
    ./cursor.nix
    ./styles.nix
    ./htop.nix
    ./alias.nix
    ./ssh.nix
    ./pet.nix
  ];

  config = lib.mkIf config.features.cli.utilities.enable {
    services.kdeconnect.enable = true;
  };
}
