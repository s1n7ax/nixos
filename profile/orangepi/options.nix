{ ... }:
{
  settings = {
    network.backend = "networkmanager";
  };

  # A browser and the coding agents, on Hyprland.
  features = {
    terminal = {
      kitty.enable = true;
    };

    desktop = {
      dconf.enable = true;
      hyprland.enable = true;
      xdg.enable = true;
      rofi.enable = true;
      cursor.enable = true;
      styles.enable = true;
    };

    hardware = {
      audio.enable = true;
      firmware.enable = true;
    };

    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };
      mdns.enable = true;
    };

    web = {
      enable = true;
      browser.enable = true;
    };

    tools = {
      downloading.enable = true;
    };

    development = {
      git.enable = true;
      github.enable = true;
      ai = {
        enable = true;
        claude.enable = true;
        pi.enable = true;
      };
    };
  };
}
