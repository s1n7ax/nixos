{ lib, config, ... }:
lib.mkIf config.features.cli.starship.enable {
  programs.starship = {
    enable = true;
    enableZshIntegration = config.settings.shell == "zsh";
    enableFishIntegration = config.settings.shell == "fish";
  };
}
