{ ... }:
{
  features = {
    desktop.dconf.enable = true;

    development.docker.enable = true;

    security.gpg.enable = true;

    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };
    };
  };

  imports = [
    ../common/configuration.nix

    ./hardware-configuration.nix
    ./gpg.nix
  ];
}
