{
  inputs,
  settings,
  ...
}:
{
  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";
  home.stateVersion = "24.05";

  imports = [
    inputs.sops-nix.homeManagerModules.sops
    "${inputs.secrets}/modules/home-manager.nix"

    ../../system/home-manager/packages
  ];
}
