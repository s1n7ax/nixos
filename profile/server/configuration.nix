{ ... }:
{
  features = {
    desktop = {
      enable = false;
      hyprland.enable = false;
      xdg.enable = false;
      kdeconnect.enable = false;
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
    ./hardware-configuration.nix
    # ./gpg.nix

    ../common/configuration.nix

    ../../system/core/boot.nix
    ../../system/core/network-manager.nix
    ../../system/core/pipewire.nix
    ../../system/core/polkit.nix

    ../../system/utils/applications.nix
    ../../system/utils/services.nix
    ../../system/utils/virtualbox.nix
    ../../system/utils/virt-manager.nix
    ../../system/utils/xdg.nix

    ../../system/hardware/bluetooth.nix
    ../../system/hardware/openrgb.nix

    ../../system/mounts/cloud-storages.nix
  ];
}
