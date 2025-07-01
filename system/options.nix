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
    terminal = mkOption {
      type = types.str;
      default = "kitty";
      description = "Default terminal emulator to use.";
    };
  };

  options.features = {
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

    security = {
      gpg = {
        enable = mkEnableOption "GnuPG agent";
      };
    };

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

    services = {
      enable = mkEnableOption "additional system services";
    };

    storage = {
      cloud = {
        enable = mkEnableOption "cloud storage mounts";
      };
    };

    network = {
      ssh = {
        enable = mkEnableOption "OpenSSH server";
        agent = {
          enable = mkEnableOption "SSH agent support";
        };
      };
    };

    homelab = {
      wireguard = {
        enable = mkEnableOption "Wireguard VPN";
      };

      frigate = {
        enable = mkEnableOption "Frigate NVR";
      };

      home-assistant = {
        enable = mkEnableOption "Home Assistant";
      };

      mqtt = {
        enable = mkEnableOption "MQTT broker";
      };

      z2m = {
        enable = mkEnableOption "Zigbee2MQTT";
      };

      adguard = {
        enable = mkEnableOption "AdGuard DNS filtering";
      };

      homepage = {
        enable = mkEnableOption "Homepage dashboard";
      };

      entertainment = {
        enable = mkEnableOption "Entertainment services";

        jellyfin = {
          enable = mkEnableOption "Jellyfin media server";
        };

        prowlarr = {
          enable = mkEnableOption "Prowlarr indexer manager";
        };

        sonarr = {
          enable = mkEnableOption "Sonarr TV series management";
        };

        radarr = {
          enable = mkEnableOption "Radarr movie management";
        };

        qbittorrent = {
          enable = mkEnableOption "qBittorrent client";
        };
      };
    };

    productivity = {
      enable = mkEnableOption "Productivity tools";

      video-production = {
        camera = {
          enable = mkEnableOption "External camera support for video production";
        };
        screen-capture = {
          enable = mkEnableOption "Screen capture tools for video production";
        };
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

      firefox.librewolf = {
        enable = mkEnableOption "LibreWolf browser";
      };
    };

    presentation = {
      enable = mkEnableOption "Presentation tools";
    };

    development = {
      llm = {
        enable = mkEnableOption "LLM tools";
      };
      ai = {
        enable = mkEnableOption "AI development tools and assistants";
        claude = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Claude Code AI assistant";
          };
        };
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
