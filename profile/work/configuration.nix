{ ... }:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix

    ../../system/core/boot.nix
    ../../system/core/network-manager.nix
    ../../system/core/pipewire.nix
    ../../system/core/polkit.nix

    ../../system/utils/applications.nix
    ../../system/utils/services.nix
    ../../system/utils/xdg.nix

    ../../system/hardware/bluetooth.nix
  ];

  package = {
    docker.enable = true;
  };
}
