{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.terminal.wezterm.enable {
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    package = inputs.wezterm.packages.${pkgs.stdenv.hostPlatform.system}.default;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      -- theme
      config.color_scheme = 'Catppuccin Mocha'

      -- fonts
      config.font = wezterm.font "${config.settings.font.name}"
      config.font_size = ${config.settings.font.size}
      config.max_fps = 144
      config.enable_tab_bar = false


      return config
    '';
  };
}
