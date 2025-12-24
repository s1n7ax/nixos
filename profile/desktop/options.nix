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
      firmware.enable = true;
    };

    virtualization = {
      docker.enable = false;
      podman.enable = true;
      virtualbox.enable = true;
      virt-manager.enable = true;
      waydroid.enable = true;
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
      monitoring.enable = true;
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
      mobile.enable = true;
    };

    web = {
      enable = true;
      browser.enable = true;
      firefox.librewolf.enable = true;
    };

    presentation = {
      enable = true;
    };

    tools = {
      downloading.enable = true;
    };

    development = {
      llm.enable = true;
      ai.enable = true;
      github.enable = true;
      c.enable = true;
      virtualization.enable = true;
      java.enable = true;
      javascript.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      python.enable = true;
      rust.enable = true;
      sh.enable = true;
      toml.enable = true;
      yaml.enable = true;
      database.enable = true;
      web.enable = true;
      ide.enable = true;
      ci.enable = true;
    };
  };
}
