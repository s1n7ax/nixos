{ settings, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = settings.shell == "zsh";
    enableFishIntegration = settings.shell == "fish";
  };
}
