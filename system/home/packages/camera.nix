{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.camera.enable = lib.mkEnableOption "camera related packages";

  config = lib.mkIf config.package.camera.enable { home.packages = with pkgs; [ gphoto2 ]; };
}
