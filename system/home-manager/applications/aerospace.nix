{
  lib,
  config,
  ...
}:
lib.mkIf config.features.desktop.aerospace.enable {
  programs.aerospace = {
    enable = true;
    launchd.enable = true;

    # Mirrors the previous ~/.aerospace.toml. Home Manager forces
    # start-at-login = false / after-login-command = [] because launchd owns startup.
    settings = {
      after-startup-command = [
        "exec-and-forget open -a kitty"
        "exec-and-forget open -a Slack"
        "exec-and-forget open -a firefox"
      ];

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      automatically-unhide-macos-hidden-apps = false;

      on-window-detected = [
        {
          "if".app-id = "com.tinyspeck.slackmacgap";
          run = "move-node-to-workspace 3";
        }
        {
          "if".app-id = "org.mozilla.firefox";
          run = "move-node-to-workspace 4";
        }
        {
          "if".app-id = "com.google.Chrome";
          run = "move-node-to-workspace 4";
        }
        {
          "if".app-id = "app.zen-browser.zen";
          run = "move-node-to-workspace 4";
        }
      ];

      key-mapping.preset = "qwerty";

      gaps = {
        inner.horizontal = 0;
        inner.vertical = 0;
        outer.left = 0;
        outer.bottom = 0;
        outer.top = 0;
        outer.right = 0;
      };

      mode.main.binding = {
        # Match Hyprland-style: Super+Enter opens a terminal
        cmd-enter = "exec-and-forget open -na kitty";

        # Focus (Colemak-friendly, match Hyprland directions)
        cmd-m = "focus left";
        cmd-n = "focus down";
        cmd-e = "focus up";
        cmd-i = "focus right";

        # Move focused window (match Hyprland Super+Shift+M/I/E/N)
        cmd-shift-m = "move left";
        cmd-shift-i = "move right";
        cmd-shift-e = "move up";
        cmd-shift-n = "move down";

        # Workspaces
        cmd-a = "workspace 1";
        cmd-r = "workspace 2";
        cmd-s = "workspace 3";
        cmd-t = "workspace 4";
        cmd-z = "workspace 5";
        cmd-x = "workspace 6";
        cmd-7 = "workspace 7";
        cmd-8 = "workspace 8";
        cmd-9 = "workspace 9";

        # Move node to workspace
        cmd-shift-a = "move-node-to-workspace 1";
        cmd-shift-r = "move-node-to-workspace 2";
        cmd-shift-s = "move-node-to-workspace 3";
        cmd-shift-t = "move-node-to-workspace 4";
        cmd-shift-z = "move-node-to-workspace 5";
        cmd-shift-x = "move-node-to-workspace 6";
        cmd-shift-7 = "move-node-to-workspace 7";
        cmd-shift-8 = "move-node-to-workspace 8";
        cmd-shift-9 = "move-node-to-workspace 9";

        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
        alt-shift-semicolon = "mode service";

        # Match Hyprland: Super+G closes; Super+Alt+T opens Chrome Incognito
        cmd-g = "close";
        cmd-alt-t = ''exec-and-forget open -na "Google Chrome" --args --incognito'';

        cmd-q = "layout tiles horizontal vertical";
        cmd-w = "layout accordion horizontal vertical";
      };

      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];

        alt-shift-h = [
          "join-with left"
          "mode main"
        ];
        alt-shift-j = [
          "join-with down"
          "mode main"
        ];
        alt-shift-k = [
          "join-with up"
          "mode main"
        ];
        alt-shift-l = [
          "join-with right"
          "mode main"
        ];

        down = "volume down";
        up = "volume up";
        shift-down = [
          "volume set 0"
          "mode main"
        ];
      };
    };
  };
}
