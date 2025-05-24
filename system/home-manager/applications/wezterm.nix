{
  pkgs,
  inputs,
  settings,
  ...
}:
{
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      -- theme
      config.color_scheme = 'Catppuccin Mocha'

      -- fonts
      config.font = wezterm.font "${settings.font.name}"
      config.font_size = ${settings.font.size}
      config.max_fps = 144
      config.enable_tab_bar = false


      return config
    '';
  };
}
