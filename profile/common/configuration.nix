{
  inputs,
  pkgs,
  config,
  ...
}:
let
  username = config.settings.username;
in
{
  config.settings = {
    username = "s1n7ax";
    shell = "fish";
    wm = {
      name = "hyprland";
      # package = pkgs.hyprland;
    };
    cursor = {
      name = "Bibata-Modern-Ice";
      # package = pkgs.bibata-cursors;
      size = 32;
    };
    font = {
      name = "Iosevka Nerd Font Mono";
      size = 18;
    };
    icon = {
      name = "Tela-circle-dark";
      # package = pkgs.tela-circle-icon-theme;
    };
    terminal = "kitty";
  };

  config.networking.hostName = username;
  config.time.timeZone = "Asia/Colombo";
  config.programs.${config.settings.shell}.enable = true;

  config.users.users.${username} = {
    shell = pkgs.${config.settings.shell};
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
      "coral" # for google coral
    ];
  };

  config.users.groups.${username} = { };

  config.environment.systemPackages = [ pkgs.home-manager ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  config.system.stateVersion = "23.05"; # Did you read the comment?

  config.nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  imports = [
    inputs.sops-nix.nixosModules.sops
    "${inputs.secrets}/modules/nixos.nix"

    ./firewall.nix

    ../../system/options.nix

    ../../system/nixos/core/boot.nix
    ../../system/nixos/core/network-manager.nix
    ../../system/nixos/core/pipewire.nix
    ../../system/nixos/core/polkit.nix
    ../../system/nixos/core/ssh.nix

    ../../system/nixos/hardware/bluetooth.nix
    ../../system/nixos/hardware/nvidia.nix
    ../../system/nixos/hardware/openrgb.nix
    ../../system/nixos/hardware/coral.nix

    ../../system/nixos/mounts/cloud-storages.nix

    ../../system/nixos/utils/applications.nix
    ../../system/nixos/utils/docker.nix
    ../../system/nixos/utils/podman.nix
    ../../system/nixos/utils/services.nix
    ../../system/nixos/utils/virt-manager.nix
    ../../system/nixos/utils/virtualbox.nix
    ../../system/nixos/utils/xdg.nix
  ];

}
