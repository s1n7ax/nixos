{ pkgs, config, lib, ... }:
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = false;
    };
    mime.enable = true;
    portal.enable = lib.mkForce (config.features.desktop.xdg.enable);
    mimeApps = {
      enable = true;

      associations.removed = {
        "image/png" = [
          "firefox.desktop"
        ];
      };
      defaultApplications =
        let
          image_viewers = [
            "nsxiv.desktop"
            "org.kde.gwenview.desktop"
          ];
          web_content = [
            "firefox.desktop"
          ];
          players = [ "vlc.desktop" ];
        in
        {
          "image/png" = image_viewers;
          "image/jpeg" = image_viewers;
          "image/webp" = image_viewers;
          "application/pdf" = [ "org.pwmt.zathura.desktop" ];

          # web content
          "text/html" = web_content;
          "text/xml" = web_content;
          "application/xhtml+xml" = web_content;
          "application/vnd.mozilla.xul+xml" = web_content;
          "text/mml" = web_content;
          "x-scheme-handler/http" = web_content;
          "x-scheme-handler/https" = web_content;
          "video/mp4" = players;
          "video/x-matroska" = players;
        };
    };
  } // lib.optionalAttrs config.features.desktop.xdg.enable {
    portal = {
      enable = true;
      configPackages = [ config.settings.wm.package ];
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
    };
  };
}
