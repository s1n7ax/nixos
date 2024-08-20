{ ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../system/core/boot.nix
    ../../system/core/network-manager.nix
    ../../system/core/pipewire.nix
    ../../system/core/polkit.nix

    ../../system/utils/applications.nix
    ../../system/utils/docker.nix
    ../../system/utils/xdg.nix

    ../../system/hardware/bluetooth.nix
  ];
}
