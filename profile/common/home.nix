{
  inputs,
  settings,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";
  home.stateVersion = "24.05";

  sops = {
    age.keyFile = ".config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets.yaml;

    secrets.hello = {
      path = "testing.txt";
    };
  };
}
