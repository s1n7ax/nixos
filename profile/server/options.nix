{
  features = {
    desktop.dconf.enable = true;

    virtualization = {
      docker.enable = true;
      podman.enable = false;
    };

    security.gpg.enable = true;

    hardware = {
      coral.enable = true;
      firmware.enable = true;
    };

    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };
      monitoring.enable = true;
    };

    tools = {
      downloading.enable = true;
    };

    development = {
      nix.enable = true;
      javascript.enable = true;
      ai.enable = true;
    };

    homelab = {
      wireguard.enable = true;
      frigate.enable = true;
      mqtt.enable = true;
      home-assistant.enable = true;
      z2m.enable = true;
      adguard.enable = true;
      homepage.enable = true;

      entertainment = {
        enable = true;
        jellyfin.enable = true;
        prowlarr.enable = true;
        sonarr.enable = true;
        radarr.enable = true;
        qbittorrent.enable = true;
      };
    };
  };
}
