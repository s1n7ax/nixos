{ pkgs, ... }: {
  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  xdg.autostart.enable = true;
}

