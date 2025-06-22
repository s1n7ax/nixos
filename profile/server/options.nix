{
  features = {
    desktop = {
      dconf.enable = true;
      hyprland.enable = true;
      xdg.enable = true;
      kdeconnect.enable = true;
    };

    security = {
      gpg.enable = true;
    };

    hardware = {
      bluetooth.enable = true;
      nvidia.enable = true;
      openrgb.enable = false;
      audio.enable = true;
      coral.enable = false;
    };

    virtualization = {
      docker.enable = true;
      podman.enable = false;
      virtualbox.enable = false;
      virt-manager.enable = true;
    };

    services = {
      enable = true;
    };

    storage = {
      cloud.enable = true;
    };

    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };
    };

    productivity = {
      enable = true;
      video-production.camera.enable = true;
      video-production.screen-capture.enable = true;
    };

    multimedia = {
      enable = true;
      video.enable = true;
      audio.enable = true;
      gaming.enable = true;
    };

    web = {
      enable = true;
      browser.enable = true;
    };

    presentation = {
      enable = true;
    };

    development = {
      nix.enable = true;
    };
  };
}
