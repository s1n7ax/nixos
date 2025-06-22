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
}
