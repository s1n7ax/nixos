{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./dunst.nix
    ./home-manager.nix
    ./vifm.nix
    ./yazi.nix
    ./rofi.nix
    ./xdg.nix
    ./zathura.nix
    ./neovim.nix
    ./cursor.nix
    ./styles.nix
    ./htop.nix
    ./alias.nix
    ./ssh.nix
    ./pet.nix
  ];

  config = lib.mkIf config.features.cli.utilities.enable {
    services.kdeconnect.enable = true;

    home.packages = with pkgs; [
      pass

      # file managers
      thunar
      tumbler
      vifm

      # audio controls
      #pavucontrol
      wiremix
      easyeffects

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
      kdePackages.gwenview

      # other
      wl-clipboard
      trash-cli
      appimage-run
      xdg-utils
      tldr

      # networking
      dig
      traceroute
    ];
  };
}
