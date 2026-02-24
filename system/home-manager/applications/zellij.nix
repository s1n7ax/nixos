{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.features.tools.zellij.enable {
    programs.zellij = {
      enable = true;
      enableFishIntegration = false;
      settings = {
        theme = "tokyo-night";
        simplified_ui = true;
        show_startup_tips = false;
        pane_frames = false;
        hide_session_name = true;
        layout = {
          pane = { };
        };
        plugins = { };
        keybinds._props.clear-defaults = true;
        keybinds."shared_except \"locked\""._children = [
          {
            bind = {
              _args = [
                "Alt q"
              ];
              _children = [
                { Quit = { }; }
              ];
            };
          }
          {
            bind = {
              _args = [
                "Alt d"
              ];
              _children = [
                { Detach = { }; }
              ];
            };
          }
        ];
      };
    };
  };
}
