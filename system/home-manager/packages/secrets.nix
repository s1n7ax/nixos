{ inputs, pkgs, ... }:
let
  secrets = builtins.toString inputs.secrets;
in
{
  home.packages = with pkgs; [
    sops
    age
  ];

  sops = {
    age.keyFile = ".config/sops/age/keys.txt";
    defaultSopsFile = "${secrets}/secrets.yaml";

    secrets.hello = { };
  };
}
