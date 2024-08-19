{ ... }:
{
  programs.kdeconnect.enable = true;
  programs.dconf.enable = true;
  programs.gnupg.agent = {
    enable = true;
  };
}
