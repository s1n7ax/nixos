{
  config,
  lib,
  inputs,
  ...
}:
let
  cursor_name = config.settings.cursor.name;
  cursor_size = config.settings.cursor.size;
in
{
  disabledModules = [ "services/window-managers/hyprland.nix" ];

  imports = [
    "${inputs.home-manager-master}/modules/services/window-managers/hyprland.nix"
  ];

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;

      wallpaper = {
        monitor = "";
        path = "~/.wallpaper/wallpaper";
        fit_mode = "cover";
      };
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = config.settings.wm.package;
    configType = "lua";
    xwayland.enable = true;

    settings = {
      config = {
        xwayland = {
          force_zero_scaling = true;
        };

        input = {
          kb_layout = "us";
          repeat_delay = 190;
          repeat_rate = 200;
          follow_mouse = 1;
          touchpad = {
            natural_scroll = false;
          };
          sensitivity = -0.6;
          accel_profile = "flat";
          scroll_points = "1 1";
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 5;
          "col.active_border" = {
            colors = [
              "rgba(8a1671ff)"
              "rgba(8a132fff)"
            ];
            angle = 45;
          };
          "col.inactive_border" = "rgba(1c1b1c01)";
          layout = "master";
        };

        decoration = {
          shadow = {
            enabled = false;
            range = 4;
          };
          rounding = 10;
          blur = {
            enabled = false;
            size = 5;
            passes = 3;
            vibrancy = 0.5;
          };
        };

        master = {
          new_status = "slave";
        };
      };

      env = [
        { _args = [ "XCURSOR_THEME" cursor_name ]; }
        { _args = [ "XCURSOR_SIZE" cursor_size ]; }
        { _args = [ "HYPRCURSOR_THEME" cursor_name ]; }
        { _args = [ "HYPRCURSOR_SIZE" cursor_size ]; }

        { _args = [ "XDG_CURRENT_DESKTOP" "Hyprland" ]; }
        { _args = [ "XDG_SESSION_TYPE" "wayland" ]; }
        { _args = [ "XDG_SESSION_DESKTOP" "Hyprland" ]; }
        { _args = [ "QT_QPA_PLATFORM" "wayland;xcb" ]; }
        { _args = [ "QT_QPA_PLATFORMTHEME" "qt6ct" ]; }
        { _args = [ "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1" ]; }
        { _args = [ "QT_AUTO_SCREEN_SCALE_FACTOR" "1" ]; }
        { _args = [ "MOZ_ENABLE_WAYLAND" "1" ]; }
        { _args = [ "GDK_SCALE" "1" ]; }

        { _args = [ "LIBVA_DRIVER_NAME" "nvidia" ]; }
        { _args = [ "__GLX_VENDOR_LIBRARY_NAME" "nvidia" ]; }
        { _args = [ "ELECTRON_OZONE_PLATFORM_HINT" "auto" ]; }
      ];

      monitor = {
        output = "";
        mode = "3440x1440@144.00Hz";
        position = "auto";
        scale = 1.25;
      };

      animation = [
        {
          leaf = "workspaces";
          enabled = true;
          speed = 1;
          curve = "default";
        }
        {
          leaf = "windows";
          enabled = false;
        }
        {
          leaf = "fade";
          enabled = false;
        }
      ];

      on = {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("${config.settings.terminal}")
              hl.exec_cmd("xdg-open 'https://'")
            end'')
        ];
      };
    };

    extraConfig = builtins.readFile ./hyprland/binds.lua;
  };
}
