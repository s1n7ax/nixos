{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  imports = [ ./hardware-configuration.nix ];

  #--------------------------------------------------------------------#
  #                                BOOT                                #
  #--------------------------------------------------------------------#
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];
  boot.supportedFilesystems = [ "ntfs" ];

  #--------------------------------------------------------------------#
  #                               NVIDIA                               #
  #--------------------------------------------------------------------#
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  #--------------------------------------------------------------------#
  #                              SECURITY                              #
  #--------------------------------------------------------------------#
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  #--------------------------------------------------------------------#
  #                              PROGRAMS                              #
  #--------------------------------------------------------------------#

  programs.zsh.enable = true;

  programs.dconf.enable = true;

  programs.gnupg.agent = { enable = true; };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.kdeconnect.enable = true;

  #--------------------------------------------------------------------#
  #                              PIPEWIRE                              #
  #--------------------------------------------------------------------#
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;

    wireplumber.enable = true;

    alsa.support32Bit = true;
  };

  #--------------------------------------------------------------------#
  #                              SERVICES                              #
  #--------------------------------------------------------------------#
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  services.udisks2.enable = true;
  services.vnstat.enable = true;
  services.openssh = {
    enable = true;
    allowSFTP = true;
  };
  services.blueman.enable = true;
  services.udev.packages = [ pkgs.android-udev-rules ];

  #--------------------------------------------------------------------#
  #                              HARDWARE                              #
  #--------------------------------------------------------------------#
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  #--------------------------------------------------------------------#
  #                               OTHER                                #
  #--------------------------------------------------------------------#
  networking.hostName = "s1n7ax";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Colombo";

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

  # recommended for pipewire

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  xdg.autostart.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.groups."s1n7ax" = { };
  users.users.s1n7ax = {
    shell = pkgs.zsh;
    isNormalUser = true;
    group = "s1n7ax";
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "pipewire"
      "docker"
      "adbusers" # for android tools
    ];
    packages = with pkgs; [
      qt6.qtwayland
      pass-wayland
      swaybg
      home-manager
      virt-manager
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  # ];
  # This is used to downgrade the docker version to something older
  # Newer version causes docker buildx to throw an error
  # More info:
  # https://github.com/devcontainers/feature-starter/issues/72
  nixpkgs.overlays = [
    (let
      pinnedPkgs = import (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "b6bbc53029a31f788ffed9ea2d459f0bb0f0fbfc";
        sha256 = "sha256-JVFoTY3rs1uDHbh0llRb1BcTNx26fGSLSiPmjojT+KY=";
      }) { };
    in final: prev: { docker = pinnedPkgs.docker; })
  ];

  virtualisation = {
    virtualbox.host.enable = true;
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
    docker = {
      enable = true;
      enableNvidia = true;
    };
  };

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
