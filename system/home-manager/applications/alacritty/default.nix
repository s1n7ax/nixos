{
  pkgs,
  settings,
  config,
  ...
}:

{
  home.file = {
    ".config/alacritty/keys.toml".source = ./config/keys.toml;
  };

  home.packages = [ pkgs.alacritty-theme ];
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 19;
        builtin_box_drawing = true;
        normal.family = "${settings.font.name}";
      };

      cursor = {
        style = {
          shape = "Beam";
        };
      };

      window = {
        decorations = "none";
        blur = false;
        opacity = 1;
        padding.x = 15;
        padding.y = 0;
      };

      general = {
        import = [
          "${pkgs.alacritty-theme}/catppuccin_mocha.toml"
          "~/.config/alacritty/keys.yml"
        ];
      };
    };
  };
}
