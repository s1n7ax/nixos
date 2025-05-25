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
    ../common/configuration.nix

    ./hardware-configuration.nix
    ./gpg.nix
    ../../system/nixos/profile/desktop
  ];
}
