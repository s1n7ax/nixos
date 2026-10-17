{ pkgs-unstable, lib, ... }:
{
  settings = {
    network.backend = "networkmanager";
    wm.package = lib.mkForce pkgs-unstable.hyprland;
    wm.portalPackage = pkgs-unstable.xdg-desktop-portal-hyprland;
  };

  features = {
    terminal = {
      kitty.enable = true;
    };

    desktop = {
      dconf.enable = true;
      hyprland.enable = true;
      hyprwhspr.enable = true;
      sinhala.enable = true;
      xdg.enable = true;
      kdeconnect.enable = true;
      dunst.enable = true;
      rofi.enable = true;
      cursor.enable = true;
      styles.enable = true;
      zathura.enable = true;
    };

    security = {
      gpg.enable = true;
    };

    hardware = {
      bluetooth = {
        enable = true;
        reconnectAudio = true;
      };
      nvidia.enable = true;
      openrgb.enable = false;
      audio.enable = true;
      coral.enable = false;
      firmware.enable = true;
      power-profile = {
        enable = true;
        # GPP0, the CPU's PCIe port 00:01.1, wakes this Gigabyte B550 board
        # ~6 s after every suspend (one PME event per suspend).
        idle.noWakeupDevices = [ "0000:00:01.1" ];
        # Logitech Unifying receiver (MX Master 3): the kernel lets only
        # keyboards wake the PC.
        idle.wakeupUsbDevices = [ "046d:c52b" ];
      };
    };

    virtualization = {
      microvm.enable = true;
    };

    services = {
      enable = true;
    };

    storage = {
      cloud.enable = true;
    };

    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };
      mdns.enable = true;
      monitoring.enable = true;
    };

    productivity = {
      enable = true;
      video-production.camera.enable = true;
      video-production.screen-capture.enable = true;
    };

    multimedia = {
      enable = true;
      video.enable = true;
      video.mpv.enable = true;
      audio.enable = true;
      gaming.enable = true;
      mobile.enable = true;
    };

    web = {
      enable = true;
      browser.enable = true;
      firefox.librewolf.enable = true;
    };

    presentation = {
      enable = true;
    };

    readAloud = {
      enable = true;
      voice = "en_US-amy-medium";
    };

    tools = {
      downloading.enable = true;
    };

    cli = {
      alias.enable = true;
    };

    development = {
      ai = {
        enable = true;
        claude.enable = true;
        pi.enable = true;
        mcp = {
          nixos.enable = true;
          playwright.enable = true;
          context7.enable = true;
          svelte.enable = true;
          nextjs.enable = true;
          tailwindcss.enable = true;
          chakra-ui.enable = true;
          jira.enable = false;
          home-assistant.enable = false;
        };
      };
      git.enable = true;
      github.enable = true;
      javascript.enable = true;
      jsonnet.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      sh.enable = true;
      web.enable = true;
    };
  };
}
