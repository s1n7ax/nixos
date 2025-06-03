{ ... }:
{
  features = {
    desktop.dconf.enable = true;

    development.docker.enable = true;
    development.podman.enable = true;

    security.gpg.enable = true;

    hardware.coral.enable = true;

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
    ../../system/nixos/profile/server
  ];
}
