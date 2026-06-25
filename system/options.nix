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
        default = 16;
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
    storagePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to the large storage mount point (e.g., /storage for HDD). Set to null if not using external storage.";
    };
    storageHddPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to a secondary storage mount point (e.g., /storage-hdd RAID enclosure) used as additional ARR-stack media storage. Set to null if not using a second drive.";
    };
    network = {
      backend = mkOption {
        type = types.enum [
          "networkmanager"
          "iwd"
        ];
        default = "networkmanager";
        description = "Network backend to use (NetworkManager or iwd).";
      };
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

      hyprwhspr = {
        enable = mkEnableOption "hyprwhspr-rs speech-to-text dictation";
      };

      xdg = {
        enable = mkEnableOption "XDG desktop portals";
      };

      kdeconnect = {
        enable = mkEnableOption "KDE Connect";
      };

      dunst = {
        enable = mkEnableOption "Dunst notification daemon";
      };

      rofi = {
        enable = mkEnableOption "Rofi application launcher";
      };

      fuzzel = {
        enable = mkEnableOption "Fuzzel application launcher";
      };

      cursor = {
        enable = mkEnableOption "Pointer cursor theme";
      };

      styles = {
        enable = mkEnableOption "GTK/Qt theming";
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

      firmware = {
        enable = mkEnableOption "Hardware firmware support";
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

      waydroid = {
        enable = mkEnableOption "Waydroid Android container";
      };

      microvm = {
        enable = mkEnableOption "microvm.nix host (lightweight NixOS VMs)";
      };
    };

    services = {
      enable = mkEnableOption "additional system services";
    };

    storage = {
      cloud = {
        enable = mkEnableOption "cloud storage mounts";
      };
      dropbox = {
        enable = mkEnableOption "Dropbox cloud storage";
      };
      googlePhotos = {
        enable = mkEnableOption "Google Photos cloud storage";
      };
    };

    network = {
      ssh = {
        enable = mkEnableOption "OpenSSH server";
        agent = {
          enable = mkEnableOption "SSH agent support";
        };
      };

      monitoring = {
        enable = mkEnableOption "Network monitoring tools";
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

      pairdrop = {
        enable = mkEnableOption "PairDrop peer-to-peer file sharing service";
      };

      homepage = {
        enable = mkEnableOption "Homepage dashboard";
      };

      node-red = {
        enable = mkEnableOption "Node-RED flow-based automation";
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

      mobile = {
        enable = mkEnableOption "Mobile app emulation and development tools";
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

    tools = {
      downloading = {
        enable = mkEnableOption "downloading tools like wget, curl";
      };
      zellij = {
        enable = mkEnableOption "Zellij terminal multiplexer";
      };
      tmux = {
        enable = mkEnableOption "tmux terminal multiplexer";
      };
    };

    development = {
      llm = {
        enable = mkEnableOption "LLM tools";
      };
      ai = {
        enable = mkEnableOption "AI development tools and assistants";
        opencode = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "OpenCode AI assistant";
          };
        };
        claude = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Claude Code AI assistant";
          };
        };
        headroom = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Headroom context-compression proxy in front of Claude Code (requires features.virtualization.podman)";
          };
          port = mkOption {
            type = types.port;
            default = 8787;
            description = "Loopback port the Headroom proxy listens on";
          };
        };
      };
      git = {
        enable = mkEnableOption "Git version control";
      };
      github = {
        enable = mkEnableOption "GitHub CLI";
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
      virtualization = {
        enable = mkEnableOption "Virtualization development tools";
      };
      editorconfig = {
        enable = mkEnableOption "EditorConfig settings";
      };
    };

    terminal = {
      kitty.enable = mkEnableOption "Kitty terminal emulator";
      ghostty.enable = mkEnableOption "Ghostty terminal emulator";
      alacritty.enable = mkEnableOption "Alacritty terminal emulator";
      wezterm.enable = mkEnableOption "WezTerm terminal emulator";
      st.enable = mkEnableOption "st (suckless terminal)";
    };

    shell = {
      fish.enable = mkEnableOption "Fish shell";
      zsh.enable = mkEnableOption "Zsh shell";
      nushell.enable = mkEnableOption "Nushell";
    };

    editor = {
      neovim.enable = mkEnableOption "Neovim editor";
    };

    cli = {
      eza.enable = mkEnableOption "eza (ls replacement)";
      fzf.enable = mkEnableOption "fzf fuzzy finder";
      zoxide.enable = mkEnableOption "zoxide directory jumper";
      starship.enable = mkEnableOption "Starship prompt";
      htop.enable = mkEnableOption "htop process viewer";
      lazygit.enable = mkEnableOption "lazygit TUI";
      pet.enable = mkEnableOption "pet snippet manager";
      direnv.enable = mkEnableOption "direnv environment loader";
      yazi.enable = mkEnableOption "Yazi file manager";
      vifm.enable = mkEnableOption "vifm file manager";
      nnn.enable = mkEnableOption "nnn file manager";
      zathura.enable = mkEnableOption "Zathura document viewer";
      mpv.enable = mkEnableOption "mpv media player";
      scripts.enable = mkEnableOption "personal shell scripts";
      alias.enable = mkEnableOption "shell aliases";
      utilities.enable = mkEnableOption "general CLI utilities and desktop helpers";
      rustAlternatives.enable = mkEnableOption "Rust-based CLI alternatives (bat, fd, rg, ...)";
    };

    fonts = {
      enable = mkEnableOption "font packages and fontconfig";
    };

    xdg = {
      enable = mkEnableOption "XDG user dirs, MIME associations and desktop entries";
    };

    core = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Core home-manager bootstrap (programs.home-manager self-management).";
      };
    };
  };
}
