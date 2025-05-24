{ ... }:
{
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

  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [ "s1n7ax" ];
    };
  };
}
