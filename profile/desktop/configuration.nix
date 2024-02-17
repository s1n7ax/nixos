{ pkgs, ... }:
let enableNvidia = true;
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
    ../../system/applications/virtualbox.nix
    ../../system/applications/virt-manager.nix
    (import ../../system/applications/docker.nix { inherit pkgs enableNvidia; })

    ../../system/hardware/bluetooth.nix
  ] ++ (if enableNvidia then [ ../../system/hardware/nvidia.nix ] else [ ]);

  #--------------------------------------------------------------------#
  #                               OTHER                                #
  #--------------------------------------------------------------------#

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # This is not suppored with flakes
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
