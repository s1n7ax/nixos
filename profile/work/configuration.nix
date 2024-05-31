{ pkgs, ... }:
let enableNvidia = false;
in {
  imports = [
    ./hardware-configuration.nix
    ./user.nix

    ../../system/core/systemd-boot.nix
    ../../system/core/boot-options.nix
    ../../system/core/polkit.nix
    ../../system/core/pipewire.nix
    ../../system/core/network-manager.nix

    ../../system/applications/applications.nix
    ../../system/applications/services.nix
    ../../system/applications/ssh.nix
    ../../system/applications/xdg.nix
    # ../../system/applications/virtualbox.nix
    # ../../system/applications/virt-manager.nix
    (import ../../system/applications/docker.nix { inherit pkgs enableNvidia; })

    ../../system/hardware/bluetooth.nix
  ] ++ (if enableNvidia then [ ../../system/hardware/nvidia.nix ] else [ ]);

  system.stateVersion = "23.05"; # Did you read the comment?
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
