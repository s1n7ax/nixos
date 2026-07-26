{ ... }:
{
  settings = {
    storagePath = "/storage";
    storageHddPath = "/storage-hdd";
  };

  features = {
    desktop.dconf.enable = true;

    virtualization = {
      podman.enable = true;
    };

    security.gpg.enable = true;

    hardware = {
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
      git.enable = true;
      github.enable = true;
      nix.enable = true;
      javascript.enable = true;
      ai = {
        enable = true;
        claude.enable = true;
      };
    };

    homelab = {
      wireguard.enable = true;
      frigate.enable = true;
      mqtt.enable = true;
      home-assistant.enable = true;
      z2m.enable = true;
      adguard.enable = true;
      node-red.enable = true;
      pairdrop.enable = false;
      homepage.enable = false;

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
