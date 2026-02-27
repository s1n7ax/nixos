{ config, ... }:
let
  cursor_name = config.settings.cursor.name;
  cursor_size = builtins.toString config.settings.cursor.size;
in
{
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
    # package = config.settings.wm.package;

    xwayland.enable = true;

    settings = {
      xwayland = {
        force_zero_scaling = true;
      };

      windowrule = [
        "workspace 1, match:class org.kde.digikam"
        "workspace 2, match:class steam, float on"
        "workspace 2, match:title Steam, float on"
        "workspace 3, match:class Tor Browser"
        "workspace 3, match:class obsidian"

        "workspace 4, match:class firefox"
        "workspace 4, match:class LibreWolf"

        "workspace 5, match:class com.obsproject.Studio"

        "workspace 8, match:class com.github.wwmm.easyeffects"
        "workspace 8, match:class pavucontrol"
        "workspace 8, match:class org.pulseaudio.pavucontrol"

        "float on, match:class steam, match:title Friends List"
        "float on, match:class Tor Browser"
      ];
      monitor = ",3440x1440@144.00Hz,auto,1.25";
      exec-once = [
        "xdg-open 'https://' &"
        # "${config.settings.terminal} -e bluetui &"
        # "${config.settings.terminal} -e wiremix &"
        "${config.settings.terminal} &"
      ];

      env = [
        "XCURSOR_THEME,${cursor_name}"
        "XCURSOR_SIZE,${cursor_size}"
        "HYPRCURSOR_THEME,${cursor_name}"
        "HYPRCURSOR_SIZE,${cursor_size}"

        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "MOZ_ENABLE_WAYLAND,1"
        "GDK_SCALE,1"

        "LIBVA_DRIVER_NAME,nvidia"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
      ];

      input = {
        kb_layout = "us";
        # kb_variant =
        # kb_model =
        # kb_options =
        # kb_rules =

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
        # See https://wiki.hyprland.org/Configuring/Variables/ for more

        gaps_in = 5;
        gaps_out = 10;
        border_size = 5;
        "col.active_border" = "rgba(8a1671ff) rgba(8a132fff) 45deg";
        "col.inactive_border" = "rgba(1c1b1c01)";

        layout = "master";
      };

      decoration = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
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

      animations = {
        enabled = true;

        # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

        # bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          "workspaces, 1, 1, default"
          "windows, 0"
          "fade, 0"
        ];
      };

      master = {
        # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        new_status = "slave";
      };

      gestures = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        # workspace_swipe = false;
      };

      "$mod" = "SUPER";
      "$smod" = "SUPER_SHIFT";
      "$amod" = "SUPER_ALT";

      bind = [
        # run some applications
        "$mod, P, exec, rofi -show drun"

        "$amod, T, exec, firefox"
        "$amod, S, exec, ${config.settings.terminal} -e vifm"
        "$amod, R, exec, thunar"
        "$amod, Z, exec, slurp | grim -g - - | wl-copy -t image/png"
        ''$amod, X, exec, slurp | grim -g - -t png ~/Pictures/"$(date +'screenshot %y-%m-%d %H:%M:%S').png"''

        "$amod, O, exec, poweroff"
        "$amod, P, exec, hyprctl dispatch togglefloating active && hyprctl dispatch resizeactive exact 30% 0 && hyprctl dispatch moveactive 2000 2000"

        "$smod, Q, exit,"

        "$mod, Return, exec, ${config.settings.terminal}"

        # window layouts
        ''$mod, H, exec, if [ "$(hyprctl activewindow -j | jq -r '.floating')" = "false" ]; then hyprctl dispatch togglefloating active && hyprctl dispatch resizeactive exact 35% 35% && hyprctl dispatch movewindow r && hyprctl dispatch movewindow d && hyprctl dispatch pin active; else hyprctl dispatch togglefloating active && hyprctl dispatch pin active; fi''

        "$mod, Q, fullscreenstate"
        "$mod, W, fullscreen, 1"
        "$mod, F, fullscreen, 0"
        "$mod, G, killactive,"
        "$mod, K, pin"

        "$mod, H, pseudo, # dwindle"
        "$mod, J, togglesplit, # dwindle"

        # Move focus with mod + arrow keys
        # "$mod, M, movefocus, l"
        # "$mod, I, movefocus, r"
        "$mod, N, cyclenext, next"
        "$mod, N, bringactivetotop,"
        "$mod, E, cyclenext, prev"
        "$mod, E, bringactivetotop,"
        "$mod, M, cyclenext, prev"
        "$mod, M, bringactivetotop,"
        "$mod, I, cyclenext, next"
        "$mod, I, bringactivetotop,"

        # Move focused window
        "$smod, M, movewindow, l"
        "$smod, I, movewindow, r"
        "$smod, E, movewindow, u"
        "$smod, N, movewindow, d"

        # Switch workspaces with mod + [0-9]
        "$mod, A, workspace, 1"
        "$mod, R, workspace, 2"
        "$mod, S, workspace, 3"
        "$mod, T, workspace, 4"
        "$mod, Z, workspace, 5"
        "$mod, X, workspace, 6"
        "$mod, C, workspace, 7"
        "$mod, D, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move active window to a workspace with mod + SHIFT + [0-9]
        "$mod SHIFT, A, movetoworkspace, 1"
        "$mod SHIFT, R, movetoworkspace, 2"
        "$mod SHIFT, S, movetoworkspace, 3"
        "$mod SHIFT, T, movetoworkspace, 4"
        "$mod SHIFT, Z, movetoworkspace, 5"
        "$mod SHIFT, X, movetoworkspace, 6"
        "$mod SHIFT, C, movetoworkspace, 7"
        "$mod SHIFT, D, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Scroll through existing workspaces with mod + scroll
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # "plugin:dynamic-cursors" = {
      #   enabled = true;
      #   mode = "none";
      #   shake = {
      #     enabled = true;
      #     threshold = 0.5;
      #     factor = 4;
      #     effects = false;
      #     nearest = true;
      #     ipc = true;
      #   };
      # };
    };
  };
}
