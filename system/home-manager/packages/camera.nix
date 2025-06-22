{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.video-production.camera.enable {
    home.packages = with pkgs; [ gphoto2 ];
  };
}
