{ lib, pkgs, ... }:
with lib;
{
  options.settings = {
    username = mkOption {
      type = types.str;
      default = "s1n7ax";
      description = "Username for the system.";
    };
    shell = mkOption {
      type = types.str;
      default = "fish";
      description = "Default shell for the user.";
    };
    wm = {
      name = mkOption {
        type = types.str;
        default = "hyprland";
        description = "Window manager to use.";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.hyprland;
        description = "Package for the window manager.";
      };
    };

    cursor = {
      name = mkOption {
        type = types.str;
        default = "Bibata-Modern-Ice";
        description = "Cursor theme to use.";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.bibata-cursors;
        description = "Package for the cursor theme.";
      };
      size = mkOption {
        type = types.int;
        default = 32;
        description = "Size of the cursor theme.";
      };
    };
    # cursor = {
    #   name = "Bibata-Modern-Ice";
    #   package = pkgs.bibata-cursors;
    #   size = 32;
    # };
    font = {
      name = mkOption {
        type = types.str;
        default = "Iosevka Nerd Font Mono";
        description = "Font to use in the terminal.";
      };
      size = mkOption {
        type = types.int;
        default = 18;
        description = "Font size for the terminal.";
      };
    };
    # font = {
    #   name = "Iosevka Nerd Font Mono";
    #   size = 18;
    # };
    icon = {
      name = mkOption {
        type = types.str;
        default = "Tela-circle-dark";
        description = "Icon theme to use.";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.tela-circle-icon-theme;
        description = "Package for the icon theme.";
      };
    };
    # icon = {
    #   name = "Tela-circle-dark";
    #   package = pkgs.tela-circle-icon-theme;
    # };
    terminal = mkOption {
      type = types.str;
      default = "kitty";
      description = "Default terminal emulator to use.";
    };
  };

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

      coral = {
        enable = mkEnableOption "Google Coral drivers for PCIe";
      };
    };

    # Development & Virtualization
    virtualization = {
      docker = {
        enable = mkEnableOption "Docker containerization";
      };

      podman = {
        enable = mkEnableOption "Podman containerization";
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

    homelab = {
      frigate = {
        enable = mkEnableOption "Frigate NVR";
      };
    };

    video-production = {
      camera = {
        enable = mkEnableOption "External camera support for video production";
      };
      screen-capture = {
        enable = mkEnableOption "Screen capture tools for video production";
      };
    };

    multimedia = {
      enable = mkEnableOption "Multimedia tools and codecs";

      video = {
        enable = mkEnableOption "Video playback and editing tools";
      };

      audio = {
        enable = mkEnableOption "Audio playback and editing tools";
      };

      gaming = {
        enable = mkEnableOption "Gaming tools and emulators";
      };
    };

    web = {
      enable = mkEnableOption "Web browsing and development tools";

      browser = {
        enable = mkEnableOption "Web browser";
      };
    };

    presentation = {
      enable = mkEnableOption "Presentation tools";
    };

    development = {
      llm = {
        enable = mkEnableOption "LLM tools";
      };
      c = {
        enable = mkEnableOption "C/C++ development tools";
      };
      container = {
        enable = mkEnableOption "Container development tools";
      };
      java = {
        enable = mkEnableOption "Java development tools";
      };
      javascript = {
        enable = mkEnableOption "JavaScript/TypeScript development tools";
      };
      lua = {
        enable = mkEnableOption "Lua development tools";
      };
      markdown = {
        enable = mkEnableOption "Markdown editing tools";
      };
      nix = {
        enable = mkEnableOption "Nix development tools";
      };
      python = {
        enable = mkEnableOption "Python development tools";
      };
      rust = {
        enable = mkEnableOption "Rust development tools";
      };
      sh = {
        enable = mkEnableOption "Shell scripting tools";
      };
      toml = {
        enable = mkEnableOption "TOML configuration tools";
      };
      yaml = {
        enable = mkEnableOption "YAML configuration tools";
      };
      database = {
        enable = mkEnableOption "Database development tools";
      };
      web = {
        enable = mkEnableOption "Web development tools";
      };
      ide = {
        enable = mkEnableOption "Integrated Development Environment (IDE) tools";
      };
      ci = {
        enable = mkEnableOption "Continuous Integration (CI) tools";
      };
    };
  };
}
