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

  programs.dconf.enable = true;
}
