{
  inputs,
  config,
  ...
}:
{
  home.username = config.settings.username;
  home.homeDirectory = "/home/${config.settings.username}";
  home.stateVersion = "24.05";

  imports = [
    ./options.nix
    ../../system/options.nix

    # sops
    inputs.sops-nix.homeManagerModules.sops
    "${inputs.secrets}/modules/home-manager.nix"

    ../../system/home-manager/packages
  ];

}
