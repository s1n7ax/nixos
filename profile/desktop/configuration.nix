{ ... }:
{
  features = {
    desktop = {
      enable = true;
      hyprland.enable = true;
      kdeconnect.enable = true;
      xdg.enable = true;
    };

    development = {
      virt-manager.enable = true;
      virtualbox.enable = true;
    };

    hardware = {
      audio.enable = true;
      bluetooth.enable = true;
      openrgb.enable = true;
      nvidia.enable = true;
    };

    network = {
      ssh.enable = true;
    };
    security = {
      gpg.enable = true;
    };

    services.enable = true;
    storage = {
      cloud.enable = true;
    };
  };

  imports = [
    ./hardware-configuration.nix
    ./gpg.nix
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
