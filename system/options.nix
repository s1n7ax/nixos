{
  config,
  lib,
  pkgs,
  ...
}:
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
      portalPackage = mkOption {
        type = types.package;
        default = pkgs.xdg-desktop-portal-hyprland;
        description = "xdg-desktop-portal backend for the window manager; take it from the same nixpkgs as `package`.";
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
    frigateStoragePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Mount point of the drive used exclusively for Frigate recordings (e.g., /storage, the internal SSD). Set to null on hosts that do not run Frigate.";
    };
    mediaStoragePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Mount point of the drive used exclusively for ARR-stack media (e.g., /storage-hdd, the RAID enclosure). Set to null on hosts that do not run the entertainment stack.";
    };
    mediaPaths = mkOption {
      type = types.attrsOf types.str;
      internal = true;
      readOnly = true;
      default =
        let
          # Forced by whichever consumer touches it first, in either module
          # system, so this is the only place that reliably beats the bare
          # "cannot coerce null to a string" the interpolation below would raise.
          root =
            if config.settings.mediaStoragePath == null then
              throw ''
                settings.mediaStoragePath must be set when the entertainment stack
                (sonarr/radarr/qbittorrent/jellyfin) is enabled -- the ARR containers
                bind-mount their libraries and downloads from it.
              ''
            else
              "${config.settings.mediaStoragePath}/.homelab";
        in
        {
          inherit root;
          sonarr = "${root}/sonarr";
          tv = "${root}/sonarr/tv";
          radarr = "${root}/radarr";
          movies = "${root}/radarr/movies";
          qbittorrent = "${root}/qbittorrent";
          downloads = "${root}/qbittorrent/downloads";
        };
      defaultText = literalMD "derived from `settings.mediaStoragePath`";
      description = ''
        Single source of truth for the ARR-stack directory layout under
        `settings.mediaStoragePath`. Both the NixOS tmpfiles module that creates
        these directories and the home-manager container modules that bind-mount
        them read this, so the two can never drift apart. Only meaningful when
        `settings.mediaStoragePath` is non-null.
      '';
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

      aerospace = {
        enable = mkEnableOption "AeroSpace tiling window manager (macOS)";
      };

      hyprwhspr = {
        enable = mkEnableOption "hyprwhspr-rs speech-to-text dictation";
      };

      sinhala = {
        enable = mkEnableOption "Sinhala input method (fcitx5 + m17n Singlish transliteration)";
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

      zathura = {
        enable = mkEnableOption "Zathura document viewer";
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
        reconnectAudio = mkEnableOption "connecting paired Bluetooth audio devices (headsets, speakers) after boot and after every resume";
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

      power-profile = {
        enable = mkEnableOption "runtime CPU/GPU power profiles (the `power-profile` CLI; amd-pstate-epp CPU, NVIDIA power limit)";
        profiles = mkOption {
          type = types.listOf types.str;
          internal = true;
          readOnly = true;
          default = [
            "strict"
            "short-boosts"
            "full-speed-heavy"
            "disabled"
            "full-power"
          ];
          description = "Profile names the `power-profile` CLI accepts. The scripts under system/nixos/hardware/power-profile/ list them too; keep them in sync.";
        };
        defaultProfile = mkOption {
          type = types.enum config.features.hardware.power-profile.profiles;
          default = "disabled";
          description = "Profile used until one is picked with `power-profile set`. `disabled` leaves the stock settings untouched.";
        };
        pcieAspmPolicy = mkOption {
          type = types.nullOr (
            types.enum [
              "default"
              "performance"
              "powersave"
              "powersupersave"
            ]
          );
          default = "powersave";
          description = "PCIe ASPM policy set with the `pcie_aspm.policy` kernel parameter, in every profile (like a BIOS toggle). null keeps the kernel default.";
        };
        shortBoostsMaxFreq = mkOption {
          type = types.ints.positive;
          default = 4000000;
          description = "CPU frequency cap of the Short boosts profile, in kHz. Clamped at runtime to the CPU's range.";
        };
        strictMaxFreq = mkOption {
          type = types.ints.positive;
          default = 2000000;
          description = "CPU frequency cap of the Strict profile (boost off), in kHz. Clamped at runtime to [amd_pstate_lowest_nonlinear_freq, cpuinfo_max_freq].";
        };
        shortBoostsGpuPowerLimit = mkOption {
          type = types.ints.positive;
          default = 102;
          description = "GPU power limit of the Short boosts profile, in watts: about 85 % of the baseline CS2 p95 draw (120 W). Clamped at runtime to the card's [power.min_limit, power.default_limit].";
        };

        # Desktop display per profile: the CLI switches Hyprland between
        # "eco" and "full" (system/home-manager/applications/hyprland/power-display.lua).
        display = {
          ecoMode = mkOption {
            type = types.strMatching "[0-9]+x[0-9]+@[0-9]+(\\.[0-9]+)?(Hz)?";
            default = "3440x1440@60.00Hz";
            description = "Hyprland monitor mode of the power-saving profiles (Strict caps, Short boosts, Full speed heavy), which also turn animations, blur and shadows off. After a game ends, the switch back to this mode waits for the next idle screen-off (`power-profile display apply`).";
          };
          fullMode = mkOption {
            type = types.strMatching "[0-9]+x[0-9]+@[0-9]+(\\.[0-9]+)?(Hz)?";
            default = "3440x1440@144.00Hz";
            description = "Hyprland monitor mode of Full power (forced or during a game) and Disabled (stock), with the effects as configured.";
          };
          file = mkOption {
            type = types.str;
            internal = true;
            readOnly = true;
            default = "/var/lib/power-profile/display";
            description = "Display mode the screen is in (`eco` or `full`): written by the `power-profile` CLI, read by the Hyprland config on every load.";
          };
        };

        # Game detection (the power-watch user unit).
        games = {
          apps = mkOption {
            type = types.listOf (types.strMatching "[^/[:cntrl:]]+");
            default = [ ];
            example = [
              "minecraft-launcher"
              "Game.exe"
            ];
            description = "Programs that count as games besides every Steam launch. Matches the process name, `.<name>-wrapped` or the argv0 basename (process names are cut to 15 characters, so longer names match through argv0 only).";
          };
          ignoredSteamAppIds = mkOption {
            type = types.listOf types.ints.unsigned;
            default = [ ];
            example = [ 228980 ];
            description = "Steam AppIds whose launches never count as a game (e.g. 228980, Steamworks Common Redistributables, if it lingers after a first Proton launch).";
          };
        };

        # Screen-off and lock (the power-idle and power-lock user units).
        idle = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Turn the screen off when idle and lock the session before suspend (hypridle + swaylock). Works in every profile, Disabled (stock) included.";
          };
          screenOffTimeout = mkOption {
            type = types.ints.positive;
            default = 120;
            description = "Seconds without keyboard/mouse input before the screen turns off. A running game (idle inhibitor) holds it off.";
          };
          noWakeupDevices = mkOption {
            type = types.listOf (types.strMatching "[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\\.[0-7]");
            default = [ ];
            example = [ "0000:00:01.1" ];
            description = "PCI devices (sysfs names) that must not wake the PC from suspend, e.g. a PCIe root port that wakes it seconds after every suspend. Keyboard and mouse wake through their USB controller and stay on.";
          };
          wakeupUsbDevices = mkOption {
            type = types.listOf (types.strMatching "[0-9a-f]{4}:[0-9a-f]{4}");
            default = [ ];
            example = [ "046d:c52b" ];
            description = "USB devices (vendor:product) that may wake the PC from suspend, e.g. a wireless mouse receiver. The kernel allows only keyboards by default.";
          };
          suspendTimeout = mkOption {
            type = types.nullOr types.ints.positive;
            default = 300;
            description = "Seconds without keyboard/mouse input before the PC suspends, unless something is busy (`power-profile can-sleep`); while busy it checks again every busy.retry seconds. null turns auto-suspend off.";
          };

          # What keeps the PC awake past suspendTimeout (`power-profile
          # can-sleep --explain` shows each signal).
          busy = {
            retry = mkOption {
              type = types.ints.positive;
              default = 30;
              description = "Seconds between busy checks once the suspend timeout has passed.";
            };
            cpuCores = mkOption {
              type = types.addCheck types.number (x: x > 0);
              default = 1.5;
              description = "Busy while the whole machine (dev VM included) uses at least this many CPU cores, averaged over busy.window seconds.";
            };
            networkKiBps = mkOption {
              type = types.ints.positive;
              default = 128;
              description = "Busy while the default-route interface moves at least this many KiB/s (received + sent), averaged over busy.window seconds. The dev VM's traffic goes through the host's interface.";
            };
            window = mkOption {
              type = types.ints.between 10 600;
              default = 60;
              description = "Seconds the CPU and network averages cover (sampled by the power-watch user unit every 5 s).";
            };
            agentProcesses = mkOption {
              type = types.listOf (types.strMatching "[^/[:cntrl:]]{1,15}");
              default = [
                "claude"
                ".claude-wrapped"
                "pi"
                "opencode"
                ".opencode-wrapp"
              ];
              description = "Process names (comm, at most 15 characters) of agent sessions that keep the PC awake, even idle, on the host and in busy.statusVm. Claude Code runs as `.claude-wrapped`, pi as `pi` (it sets its process title), opencode as `.opencode-wrapp` (`.opencode-wrapped` cut to 15).";
            };
            audioIgnore = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "easyeffects" ];
              description = "PipeWire output streams that never count as playing audio, matched against application.name, application.process.binary or node.name.";
            };
            statusVm = mkOption {
              type = types.nullOr (types.strMatching "[A-Za-z0-9_-]+");
              default = null;
              example = "dev-vm";
              description = "microvm.nix VM that reports its agent sessions to the host through a virtiofs share (host /run/<name>-status, guest /run/host-status). While the VM runs, a status older than 60 s counts as busy. Adding or removing the share restarts the VM on deploy.";
            };
          };
        };
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
    };

    network = {
      ssh = {
        enable = mkEnableOption "OpenSSH server";
        agent = {
          enable = mkEnableOption "SSH agent support";
        };
      };

      mdns = {
        enable = mkEnableOption "mDNS/Bonjour (advertises and resolves *.local on the LAN)";
      };

      monitoring = {
        enable = mkEnableOption "Network monitoring tools";
      };
    };

    readAloud = {
      enable = mkEnableOption "local read-aloud text-to-speech";
      rate = mkOption {
        type = types.float;
        default = 1.0;
        description = "Read-aloud speech speed; higher is faster. Piper gets a length scale of 1 / rate, macOS `say` gets round(175 * rate) words per minute.";
      };
      voice = mkOption {
        type = types.str;
        default = "en_US-lessac-medium";
        description = "Piper voice, as `<locale>-<name>-<quality>`; must be listed in system/shared/piper.nix.";
      };
      speaker = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        description = "Speaker id for multi-speaker Piper voices; null uses the voice's default.";
      };
      pulseServer = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Play the synthesized audio through this PulseAudio server instead of
          the local PipeWire daemon, e.g. `tcp:10.0.2.2:4713` for a MicroVM
          whose host serves audio. Use this where the machine has no sound card
          of its own; null plays through local PipeWire with `pw-cat`.
        '';
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

      wyoming-piper = {
        enable = mkEnableOption "the Wyoming Piper local text-to-speech server for Home Assistant";
      };

      mqtt = {
        enable = mkEnableOption "MQTT broker";
      };

      z2m = {
        enable = mkEnableOption "Zigbee2MQTT";
        permit_join_forever = mkEnableOption "the permit-join-forever extension (keeps the Zigbee network open to joins; insecure)";
      };

      dongle-m-serial-log = {
        enable = mkEnableOption "the SONOFF Dongle-M serial console logger (logs the ESP32 reset reason of every reboot while the dongle is on USB-C)";
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

      paperless = {
        enable = mkEnableOption "Paperless-ngx document management";
      };

      dongle-m-reboot-monitor = {
        enable = mkEnableOption "the SONOFF Dongle-M reboot monitor (records every coordinator reboot and sends a Home Assistant notification for each)";
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
        mpv.enable = mkEnableOption "mpv media player";
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
          yolo = mkOption {
            type = types.bool;
            default = false;
            description = "Run Claude Code in bypassPermissions mode with no permission prompts. Only for sandboxed hosts like the dev microvm";
          };
        };
        pi = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "pi-coding-agent AI assistant (github.com/badlogic/pi-mono, pi.dev)";
          };
          cursor = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Cursor provider for pi, declared through pi's packages list (requires cursor.package), so Cursor appears in pi's /login flow";
            };
            package = mkOption {
              type = types.str;
              default = "";
              description = "Pinned npm spec (npm:-prefixed) of the pi Cursor provider plugin to load, set by the host profile; only declared when cursor.enable is set and non-empty";
            };
          };
        };
        cursor = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Cursor CLI coding agent (cursor-agent, cursor.com/cli). Unrelated to features.desktop.cursor (pointer theme).";
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
        mcp = {
          nixos = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "mcp-nixos MCP server (nixpkgs, NixOS and home-manager option search)";
            };
          };
          playwright = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Playwright MCP server (browser automation)";
            };
            headless = mkOption {
              type = types.bool;
              default = false;
              description = "Run the Playwright MCP browser headless (for hosts without a display)";
            };
          };
          context7 = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Context7 MCP server (up-to-date library documentation)";
            };
          };
          svelte = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Svelte MCP server (@sveltejs/mcp, via npx)";
            };
          };
          nextjs = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Next.js MCP server (next-devtools-mcp, via npx)";
            };
          };
          tailwindcss = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Tailwind CSS MCP server (tailwindcss-mcp-server, via npx)";
            };
          };
          chakra-ui = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Chakra UI MCP server (@chakra-ui/react-mcp, via npx)";
            };
          };
          jira = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Official Atlassian remote MCP (Jira, Confluence, etc. via https://mcp.atlassian.com/v2/mcp; OAuth in the client)";
            };
          };
          slack = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Official Slack remote MCP (https://mcp.slack.com/mcp; OAuth in the client)";
            };
          };
          home-assistant = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Home Assistant MCP server (ha-mcp); reads its long-lived access token from the sops secret home-assistant/mcp_token";
            };
            url = mkOption {
              type = types.str;
              default = "http://127.0.0.1:8124";
              description = "Home Assistant base URL the MCP server connects to";
            };
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
        fnm = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "fnm Node version manager. Owns Node on PATH and auto-switches from .nvmrc/.node-version; leave off where Nix/direnv already provides Node";
          };
        };
      };
      jsonnet = {
        enable = mkEnableOption "Jsonnet development tools";
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
      playwright = {
        enable = mkEnableOption "Playwright browser automation with nix-provided Chromium";
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
      neovim = {
        enable = mkEnableOption "Neovim editor";
        useNightly = mkOption {
          type = types.bool;
          default = false;
          description = "Use nightly Neovim build instead of nixpkgs-unstable.";
        };
      };
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
