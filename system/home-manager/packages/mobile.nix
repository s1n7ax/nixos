{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.multimedia.mobile.enable {
    home.packages = with pkgs; [ waydroid ];
  };
}