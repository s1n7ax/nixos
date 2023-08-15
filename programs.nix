{config, pkgs, ...}:
{
  programs.gnupg.agent = {
    enable = true;
  #   enableSSHSupport = true;
  };

  programs.hyprland = {
    enable = true;
    nvidiaPatches = true;
    xwayland.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # ohMyZsh.enable = true;
    autosuggestions.enable = true;
    autosuggestions.async = true;
    syntaxHighlighting.enable = true;
  };

  programs.dconf.enable = true;
}
