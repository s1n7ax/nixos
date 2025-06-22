{ config, ... }:
{
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = config.settings.shell == "nu";
    enableZshIntegration = config.settings.shell == "zsh";
    enableFishIntegration = true;
  };
}
