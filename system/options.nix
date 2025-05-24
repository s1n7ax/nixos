{ lib, ... }:

with lib;

{
  options.features = {
    # Desktop Environment Features
    desktop = {
      enable = mkEnableOption "desktop environment features";

      dconf = {
        enable = mkEnableOption "Dconf configuration system";
      };

      hyprland = {
        enable = mkEnableOption "Hyprland window manager";
      };

      xdg = {
        enable = mkEnableOption "XDG desktop portals";
      };

      kdeconnect = {
        enable = mkEnableOption "KDE Connect";
      };
    };

    # Security & Authentication
    security = {
      gpg = {
        enable = mkEnableOption "GnuPG agent";
      };
    };

    # Hardware Features
    hardware = {
      bluetooth = {
        enable = mkEnableOption "Bluetooth support";
      };

      nvidia = {
        enable = mkEnableOption "NVIDIA drivers";
      };

      openrgb = {
        enable = mkEnableOption "OpenRGB for RGB lighting";
      };

      audio = {
        enable = mkEnableOption "PipeWire audio system";
      };
    };

    # Development & Virtualization
    development = {
      docker = {
        enable = mkEnableOption "Docker containerization";
      };

      virtualbox = {
        enable = mkEnableOption "VirtualBox virtualization";
      };

      virt-manager = {
        enable = mkEnableOption "libvirt/KVM virtualization";
      };
    };

    # Services
    services = {
      enable = mkEnableOption "additional system services";
    };

    # Storage & Mounts
    storage = {
      cloud = {
        enable = mkEnableOption "cloud storage mounts";
      };
    };

    # Network Services
    network = {
      ssh = {
        enable = mkEnableOption "OpenSSH server";
        agent = {
          enable = mkEnableOption "SSH agent support";
        };
      };
    };
  };
}
