{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.multimedia.video.enable {
    home.packages = with pkgs; [ vlc ];
  };
}
