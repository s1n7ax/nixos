{ pkgs-unstable, lib, ... }:
{
  settings = {
    network.backend = "networkmanager";
    wm.package = lib.mkForce pkgs-unstable.hyprland;
  };

  features = {
    terminal = {
      kitty.enable = true;
    };

    desktop = {
      dconf.enable = true;
      hyprland.enable = true;
      hyprwhspr.enable = true;
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
      bluetooth.enable = true;
      nvidia.enable = true;
      openrgb.enable = false;
      audio.enable = true;
      coral.enable = false;
      firmware.enable = true;
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

    tools = {
      downloading.enable = true;
    };

    development = {
      ai = {
        enable = true;
        claude.enable = true;
      };
      git.enable = true;
      github.enable = true;
      javascript.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      sh.enable = true;
      web.enable = true;
    };
  };
}
