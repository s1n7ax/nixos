{ ... }: {
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = false;
    enableZshIntegration = true;
    enableFishIntegration = false;
  };
}
