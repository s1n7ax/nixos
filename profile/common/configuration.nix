{
  config,
  inputs,
  pkgs,
  settings,
  ...
}:
let
  username = settings.username;
  secrets = builtins.toString inputs.secrets;
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
      "apex" # for google coral
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
    inputs.sops-nix.nixosModules.sops

    ./firewall.nix
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

  sops = {
    defaultSopsFile = "${secrets}/secrets.yaml";
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets.hello = {
      owner = config.users.users.s1n7ax.name;
      group = config.users.users.s1n7ax.group;
      path = "/etc/testing.txt";
    };
  };
}
