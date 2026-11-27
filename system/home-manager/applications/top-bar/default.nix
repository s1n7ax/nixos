{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
# The top bar: Waybar along the top of every monitor, started with the
# graphical session. Left: the Hyprland workspaces as circles (filled = the
# one shown; click to switch). Middle: the time (hover for the date). Right:
# the Tailscale item of the remote-agent app (with
# features.desktop.remote-agent), Bluetooth and Wi-Fi (click for a rofi menu)
# and the volume (scroll to change, click to mute, right-click for wiremix).
#
# Journal: `journalctl --user -u waybar`.
let
  cfg = config.features.desktop.top-bar;
  remoteAgent = config.features.desktop.remote-agent;

  menus = pkgs.callPackage ./package.nix {
    rofi = config.programs.rofi.finalPackage;
  };

  remote-agent = pkgs.callPackage ../remote-agent/package.nix {
    inherit (remoteAgent) url hostname proxyPort;
  };

  wpctl = "${pkgs.wireplumber}/bin/wpctl";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.features.desktop.rofi.enable;
        message = "features.desktop.top-bar needs features.desktop.rofi for its Bluetooth and Wi-Fi menus.";
      }
    ];

    home.packages = [
      menus.bluetooth-menu
      menus.wifi-menu
    ];

    programs.waybar = {
      enable = true;
      # Same channel as the Hyprland compositor (pkgs-unstable), so the
      # workspaces module speaks the compositor's IPC.
      package = pkgs-unstable.waybar;
      systemd.enable = true;

      settings.top = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = lib.optional remoteAgent.enable "custom/tailscale" ++ [
          "bluetooth"
          "network"
          "wireplumber"
        ];

        "hyprland/workspaces" = {
          format = "{icon}";
          # active is the focused workspace; visible the one shown on each
          # other monitor.
          format-icons = {
            active = "●";
            visible = "●";
            default = "○";
          };
        };

        clock = {
          format = "{:%H:%M}";
          tooltip-format = "{:%A, %d %B %Y}";
        };

        "custom/tailscale" = {
          exec = "${remote-agent}/bin/remote-agent bar";
          return-type = "json";
          interval = 5;
          # remote-agent signals the bar (SIGRTMIN+8, package.nix's
          # barSignal) on every state change it makes.
          signal = 8;
          on-click = "${remote-agent}/bin/remote-agent click";
        };

        bluetooth = {
          format = "󰂯";
          format-off = "󰂲";
          format-disabled = "󰂲";
          format-connected = "󰂱 {device_alias}";
          format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
          tooltip-format = "Bluetooth {status}";
          tooltip-format-connected = "Bluetooth: {num_connections} connected\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "${menus.bluetooth-menu}/bin/bluetooth-menu";
        };

        network = {
          format-wifi = "󰤨 {essid}";
          format-ethernet = "󰈀";
          format-linked = "󰈀 no IP";
          format-disconnected = "󰤮";
          tooltip-format-wifi = "Wi-Fi: {essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-ethernet = "Wired: {ifname}\n{ipaddr}";
          tooltip-format-disconnected = "Not connected";
          on-click = "${menus.wifi-menu}/bin/wifi-menu";
        };

        wireplumber = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 muted";
          format-icons = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          scroll-step = 5;
          max-volume = 100;
          on-click = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-click-right = "${config.settings.terminal} -e ${pkgs.wiremix}/bin/wiremix";
        };
      };

      style = ''
        * {
          font-family: "${config.settings.font.name}";
          font-size: 14px;
          min-height: 0;
          border: none;
          border-radius: 0;
        }

        window#waybar {
          background: rgba(17, 17, 27, 0.9);
          color: #cdd6f4;
        }

        tooltip {
          background: #11111b;
          border: 1px solid #cba6f7;
          border-radius: 8px;
        }

        #workspaces button {
          padding: 0 4px;
          color: #6c7086;
          background: transparent;
        }

        #workspaces button.active,
        #workspaces button.visible {
          color: #cba6f7;
        }

        #workspaces button.urgent {
          color: #f38ba8;
        }

        #clock,
        #custom-tailscale,
        #bluetooth,
        #network,
        #wireplumber {
          padding: 0 10px;
        }

        #custom-tailscale.connected {
          color: #a6e3a1;
        }

        #custom-tailscale.disconnected,
        #bluetooth.off,
        #bluetooth.disabled,
        #network.disconnected,
        #wireplumber.muted {
          color: #6c7086;
        }

        #custom-tailscale.connecting {
          color: #f9e2af;
        }

        #custom-tailscale.failed {
          color: #f38ba8;
        }
      '';
    };
  };
}
