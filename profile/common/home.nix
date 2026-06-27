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
    "${inputs.secrets}/modules/home-manager.nix"

    ../../system/home-manager
  ];

}
