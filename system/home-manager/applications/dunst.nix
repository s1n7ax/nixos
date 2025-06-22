{ pkgs, config, ... }:
let
  dunstConf = pkgs.fetchgit {
    url = "https://github.com/catppuccin/dunst.git";
    rev = "a72991e";
    sha256 = "1LeSKuZcuWr9z6mKnyt1ojFOnIiTupwspGrOw/ts8Yk=";
  };
in
{
  services.dunst = {
    enable = true;
    # configFile = "${dunstConf}/src/macchiato.conf";
    iconTheme = {
      inherit (config.settings.icon) name package;
    };
    settings = {
      global = {
        monitor = 0;
        follow = "mouse";
        width = 400;
        height = 400;
        origin = "top-right";
        offset = "20x20";
        scale = 0;
        notification_limit = 20;
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 0;
        progress_bar_min_width = 125;
        progress_bar_max_width = 250;
        progress_bar_corner_radius = 4;
        icon_corner_radius = 10;
        indicate_hidden = "yes";
        transparency = 10;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        text_icon_padding = 10;
        frame_width = 5;
        gap_size = 5;
        separator_color = "auto";
        sort = "yes";
        font = "${config.settings.font.name} ${toString config.settings.font.size}";
        line_height = 3;
        markup = "full";
        format = "%s\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = "no";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = "yes";
        icon_theme = config.settings.icon.name;
        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 128;
        icon_path = "$HOME/.icons/Tela-circle-dracula/16/actions:$HOME/.icons/Tela-circle-dracula/16/apps:$HOME/.icons/Tela-circle-dracula/16/devices:$HOME/.icons/Tela-circle-dracula/16/mimetypes:$HOME/.icons/Tela-circle-dracula/16/panel:$HOME/.icons/Tela-circle-dracula/16/places:$HOME/.icons/Tela-circle-dracula/16/status";
        sticky_history = "yes";
        history_length = 20;
        dmenu = ''/usr/bin/rofi -config "$HOME/.config/rofi/notification.rasi" -dmenu -p dunst:'';
        browser = "/usr/bin/xdg-open";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 10;
        ignore_dbusclose = false;
        force_xwayland = false;
        force_xinerama = false;
        mouse_left_click = "context, close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };
      experimental = {
        per_monitor_dpi = false;
      };
      Type-1 = {
        appname = "t1";
        format = "<b>%s</b>";
      };
      Type-2 = {

        appname = "t2";
        format = ''<span size="250%">%s</span>\n%b'';
      };
      urgency_critical = {

        icon = "$HOME/.config/dunst/icons/critical.svg";
        timeout = 0;
      };
      urgency_low = {
        icon = "$HOME/.config/dunst/icons/hyprdots.svg";
        timeout = 5;
      };
      urgency_normal = {

        icon = "$HOME/.config/dunst/icons/hyprdots.svg";
        timeout = 5;
      };
    };
  };
}
