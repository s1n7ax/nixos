{ inputs, ... }:

let
  secrets = builtins.toString inputs.secrets;
in
{
  sops = {
    defaultSopsFile = "${secrets}/secrets.yaml";
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets.hello = { };
  };
}
