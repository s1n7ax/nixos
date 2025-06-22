{
  features = {
    desktop.dconf.enable = true;

    virtualization = {
      docker.enable = true;
      podman.enable = true;
    };

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
