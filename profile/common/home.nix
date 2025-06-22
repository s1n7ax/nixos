{
  inputs,
  config,
  ...
}:
{
  config.settings = {
    username = "s1n7ax";
    shell = "fish";
    wm = {
      name = "hyprland";
      # package = pkgs.hyprland;
    };
    cursor = {
      name = "Bibata-Modern-Ice";
      # package = pkgs.bibata-cursors;
      size = 32;
    };
    font = {
      name = "Iosevka Nerd Font Mono";
      size = 18;
    };
    icon = {
      name = "Tela-circle-dark";
      # package = pkgs.tela-circle-icon-theme;
    };
    terminal = "kitty";
  };

  config = {
    home.username = config.settings.username;
    home.homeDirectory = "/home/${config.settings.username}";
    home.stateVersion = "24.05";
  };

  imports = [
    ../../system/options.nix

    inputs.sops-nix.homeManagerModules.sops
    "${inputs.secrets}/modules/home-manager.nix"
    ../../system/home-manager/packages
  ];

}
