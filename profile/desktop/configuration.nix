{ ... }:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./gpg.nix

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

  package = {
    nvidia.enable = true;
    docker.enable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [ "s1n7ax" ];
    };
  };
}
