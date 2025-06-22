{ config, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = config.settings.shell == "zsh";
    enableFishIntegration = config.settings.shell == "fish";
  };
}
