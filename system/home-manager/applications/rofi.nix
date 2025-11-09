{
  config,
  pkgs,
  ...
}:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    pass.enable = true;
    pass.package = pkgs.rofi-pass;

    extraConfig = {
      modi = "drun,filebrowser,window,run";
      show-icons = true;
      display-drun = " ";
      display-run = " ";
      display-filebrowser = " ";
      display-window = " ";
      drun-display-format = "{name}";
      window-format = "{w}{t}";
      font = "JetBrainsMono Nerd Font 10";
      icon-theme = config.settings.icon.name;

      kb-move-end = "";
      kb-element-next = "";
      kb-secondary-copy = "";
      kb-cancel = "Escape,Control+c";
      kb-row-down = "Control+n";
      kb-row-up = "Control+e";
      kb-mode-next = "Control+i";
      kb-mode-previous = "Control+m";
      kb-accept-entry = "Return";
    };

    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        "*" = {
          main-bg = mkLiteral "#11111be6";
          main-fg = mkLiteral "#cdd6f4ff";
          main-br = mkLiteral "#cba6f7ff";
          main-ex = mkLiteral "#f5e0dcff";
          select-bg = mkLiteral "#b4befeff";
          select-fg = mkLiteral "#11111bff";
          separatorcolor = mkLiteral "transparent";
          border-color = mkLiteral "transparent";
        };

        window = {
          height = mkLiteral "30em";
          width = mkLiteral "37em";
          transparency = "real";
          fullscreen = false;
          enabled = true;
          cursor = "default";
          spacing = mkLiteral "0em";
          padding = mkLiteral "0em";
          border-color = mkLiteral "@main-br";
          background-color = mkLiteral "@main-bg";
        };
        mainbox = {
          enabled = true;
          spacing = mkLiteral "0em";
          padding = mkLiteral "0em";
          orientation = mkLiteral "vertical";
          children = [
            "inputbar"
            "dummybox"
          ];
          background-color = mkLiteral "transparent";
        };
        dummybox = {
          padding = mkLiteral "0.5em";
          spacing = mkLiteral "0em";
          orientation = mkLiteral "horizontal";
          children = [
            "mode-switcher"
            "listbox"
          ];
          background-color = mkLiteral "transparent";
          background-image = mkLiteral "transparent";
        };

        inputbar = {
          enabled = false;
        };

        listbox = {
          padding = mkLiteral "0em";
          spacing = mkLiteral "0em";
          children = [
            "dummy"
            "listview"
            "dummy"
          ];
          background-color = mkLiteral "transparent";
          background-image = mkLiteral "transparent";
        };
        listview = {
          padding = mkLiteral "1em";
          spacing = mkLiteral "0em";
          enabled = true;
          columns = 1;
          lines = 7;
          cycle = true;
          dynamic = true;
          scrollbar = false;
          layout = mkLiteral "vertical";
          reverse = false;
          expand = false;
          fixed-height = true;
          fixed-columns = true;
          cursor = mkLiteral "default";
          background-color = mkLiteral "@main-bg";
          text-color = mkLiteral "@main-fg";
          border-radius = mkLiteral "1.5em";
        };
        dummy = {
          background-color = mkLiteral "transparent";
        };

        mode-switcher = {
          orientation = mkLiteral "vertical";
          width = mkLiteral "6.8em";
          enabled = true;
          padding = mkLiteral "3.2em 1em 3.2em 1em";
          spacing = mkLiteral "1em";
          background-color = mkLiteral "transparent";
        };
        button = {
          cursor = mkLiteral "pointer";
          border-radius = mkLiteral "3em";
          background-color = mkLiteral "@main-bg";
          text-color = mkLiteral "@main-fg";
        };
        "button selected" = {
          background-color = mkLiteral "@main-fg";
          text-color = mkLiteral "@main-bg";
        };

        element = {
          enabled = true;
          spacing = mkLiteral "1em";
          padding = mkLiteral "0.4em";
          cursor = mkLiteral "pointer";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@main-fg";
        };
        "element selected.normal" = {
          background-color = mkLiteral "@select-bg";
          text-color = mkLiteral "@select-fg";
        };
        element-icon = {
          size = mkLiteral "3em";
          cursor = mkLiteral "inherit";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "inherit";
        };
        element-text = {
          vertical-align = mkLiteral "0.5";
          horizontal-align = mkLiteral "0.0";
          cursor = mkLiteral "inherit";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "inherit";
        };

        error-message = {
          text-color = mkLiteral "@main-fg";
          background-color = mkLiteral "@main-bg";
          text-transform = mkLiteral "capitalize";
          children = [ "textbox" ];
        };

        textbox = {
          text-color = mkLiteral "inherit";
          background-color = mkLiteral "inherit";
          vertical-align = mkLiteral "0.5";
          horizontal-align = mkLiteral "0.5";
        };
      };
  };

}
