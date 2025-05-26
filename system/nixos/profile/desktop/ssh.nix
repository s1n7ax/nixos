{ ... }:
let
  publicKeys = import ../../constants/ssh-public-keys.nix;
in
{
  programs.ssh = {
    knownHosts = {
      "github.com ssh-ed25519" = {
        hostNames = [ "github.com" ];
        publicKey = publicKeys.github;
      };
      "192.168.1.110 ssh-ed25519" = {
        hostNames = [ "192.168.1.110 " ];
        publicKey = publicKeys.server;
      };
    };
  };
}
