{ settings, ... }:
let
  cursor_name = settings.cursor.name;
  cursor_size = builtins.toString settings.cursor.size;
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;
      preload = [ "~/.wallpaper/wallpaper" ];
      wallpaper = [
        "HDMI-A-1,~/.wallpaper/wallpaper"
        "eDP-1,~/.wallpaper/wallpaper"
      ];
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = settings.wm.package;

    xwayland.enable = true;

    settings = {
      xwayland = {
        force_zero_scaling = true;
      };

      windowrulev2 = [
        "workspace 1,class:(org.kde.digikam)"
        "workspace 2,class:(steam),float(0)"
        "workspace 3,class:(Tor Browser)"
        "workspace 3,class:(obsidian)"

        "workspace 4,class:(firefox)"
        "workspace 4,class:(LibreWolf)"

        "workspace 5,class:(com.obsproject.Studio)"

        "workspace 8,class:(pavucontrol)"
        "workspace 8,class:(org.pulseaudio.pavucontrol)"
        "workspace 8,class:(.blueman-manager-wrapped)"

        "float,class:(steam),title:(Friends List)"
        "float,class:(Tor Browser)"
      ];
      monitor = ",preferred,auto,1";
      exec-once = [
        "swaybg -i .wallpaper/*"
        "xdg-open 'https://' &"
        "blueman-manager& "
        "pavucontrol &"
        "alacritty &"
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

        sensitivity = -0.5;
        accel_profile = "flat";
      };

      general = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more

        gaps_in = 10;
        gaps_out = 20;
        border_size = 5;
        "col.active_border" = "rgba(8a1671ff) rgba(8a132fff) 45deg";
        "col.inactive_border" = "rgba(1c1b1c01)";

        layout = "master";
      };

      decoration = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more

        rounding = 10;

        blur = {
          enabled = true;
          size = 5;
          passes = 3;
          vibrancy = 0.5;
        };

        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };

      animations = {
        enabled = true;

        # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          "windows, 1, 1, myBezier"
          "windowsOut, 1, 1, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 1, default"
          "workspaces, 1, 1, default"
        ];
      };

      master = {
        # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        new_status = "slave";
      };

      gestures = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        workspace_swipe = false;
      };

      "$mod" = "SUPER";
      "$smod" = "SUPER_SHIFT";
      "$amod" = "SUPER_ALT";

      bind = [
        # run some applications
        "$mod, P, exec, rofi -show drun"

        "$amod, T, exec, firefox"
        "$amod, S, exec, alacritty -e vifm"
        "$amod, R, exec, thunar"
        "$amod, Z, exec, slurp | grim -g - - | wl-copy -t image/png"
        ''$amod, X, exec, grim -t png ~/Pictures/"$(date +'screenshot %y-%m-%d %H:%M:%S').png"''

        "$amod, O, exec, poweroff"

        "$smod, Q, exit,"

        "$mod, Return, exec, alacritty"

        # window layouts
        "$mod, H, togglefloating,"
        "$mod, Q, fullscreenstate"
        "$mod, W, fullscreen, 1"
        "$mod, F, fullscreen, 0"
        "$mod, G, killactive,"
        "$mod, K, pin"

        "$mod, H, pseudo, # dwindle"
        "$mod, J, togglesplit, # dwindle"

        # Move focus with mod + arrow keys
        "$mod, M, movefocus, l"
        "$mod, I, movefocus, r"
        "$mod, E, movefocus, u"
        "$mod, N, movefocus, d"

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
