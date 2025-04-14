{ settings, ... }:
{
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = settings.shell == "nu";
    enableZshIntegration = settings.shell == "zsh";
    enableFishIntegration = true;
  };
}
