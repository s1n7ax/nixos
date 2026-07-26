{ lib, config, ... }:
lib.mkIf config.features.cli.zoxide.enable {
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = config.settings.shell == "nu";
    enableZshIntegration = config.settings.shell == "zsh";
    enableFishIntegration = true;
  };
}
