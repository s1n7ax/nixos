{ pkgs, settings, ... }:
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = false;
    };

    portal = {
      enable = true;
      configPackages = [ settings.wm.package ];
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
    };
    mime.enable = true;
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
  };
}
