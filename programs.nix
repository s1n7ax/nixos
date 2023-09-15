{config, pkgs, ...}:
{
  programs.dconf.enable = true;

  programs.gnupg.agent = {
    enable = true;
  #   enableSSHSupport = true;
  };

  programs.hyprland = {
    enable = true;
    nvidiaPatches = true;
    xwayland.enable = true;
  };

  programs.kdeconnect.enable = true;
}
