{ ... }:
{
  programs.dconf.enable = true;
  programs.gnupg.agent = {
    enable = true;
  };
}
