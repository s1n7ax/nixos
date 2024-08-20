{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.players.enable = lib.mkEnableOption "video/audio player packages";

  config = lib.mkIf config.package.players.enable { home.packages = with pkgs; [ vlc ]; };
}
