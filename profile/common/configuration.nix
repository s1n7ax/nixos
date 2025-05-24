{ pkgs, settings, ... }:
let
  username = settings.username;
in
{
  networking.hostName = username;
  time.timeZone = "Asia/Colombo";
  programs.${settings.shell}.enable = true;

  users.users.${username} = {
    shell = pkgs.${settings.shell};
    isNormalUser = true;
    group = username;
    extraGroups = [
      "audio"
      "docker"
      "libvirtd"
      "network"
      "networkmanager"
      "pipewire"
      "plugdev"
      "podman"
      "video"
      "wheel"
      "adbusers"
      "disk"
    ];
  };

  users.groups.${username} = { };

  environment.systemPackages = [ pkgs.home-manager ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  imports = [
    ./firewall.nix
    ../../system/core/boot.nix
    ../../system/core/network-manager.nix
    ../../system/core/pipewire.nix
    ../../system/core/polkit.nix
    ../../system/core/ssh.nix

    ../../system/hardware/bluetooth.nix
    ../../system/hardware/nvidia.nix
    ../../system/hardware/openrgb.nix

    ../../system/mounts/cloud-storages.nix

    ../../system/utils/applications.nix
    ../../system/utils/docker.nix
    ../../system/utils/podman.nix
    ../../system/utils/services.nix
    ../../system/utils/virt-manager.nix
    ../../system/utils/virtualbox.nix
    ../../system/utils/xdg.nix
  ];
}
