{ pkgs, ... }:
{
  imports = [
    ../applications/dunst.nix
    ../applications/home-manager.nix
    ../applications/vifm.nix
    ../applications/rofi.nix
    ../applications/xdg.nix
    ../applications/zathura.nix
    ../applications/neovim.nix
    ../applications/cursor.nix
    ../applications/styles.nix
    ../applications/htop.nix
  ];

  services.kdeconnect.enable = true;

  home.packages = with pkgs; [

    pass
    # file managers
    xfce.thunar
    xfce.tumbler
    vifm

    # audio controls
    #pavucontrol
    pwvucontrol
    easyeffects

    #bluetooth
    blueman

    # downloaders
    axel
    yt-dlp

    # compress de-compress
    p7zip
    unzip

    # sync
    rclone
    sshfs

    # image
    ffmpeg_6-full
    nsxiv
    libsForQt5.gwenview

    # other
    wl-clipboard
    trash-cli
    appimage-run
    xdg-utils
    tldr
  ];
}
