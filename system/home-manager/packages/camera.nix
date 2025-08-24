{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.productivity.video-production.camera.enable {
    home.packages = with pkgs; [ gphoto2 darktable ];
  };
}
