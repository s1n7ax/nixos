{ ... }:
{
  features = {
    desktop = {
      enable = false;
      hyprland.enable = false;
      xdg.enable = false;
      kdeconnect.enable = false;
      dconf.enable = true;
    };

    hardware = {
      bluetooth.enable = false;
      audio.enable = false;
      openrgb.enable = false;
    };

    development = {
      virtualbox.enable = false;
      virt-manager.enable = false;
    };

    security = {
      gpg.enable = false;
    };

    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };

    };

    services.enable = false;
    storage.cloud.enable = false;
  };

  imports = [
    ../common/configuration.nix

    ./hardware-configuration.nix
    # ./gpg.nix
  ];
}
