{
  lib,
  config,
  pkgs,
  ...
}:
{

  imports = [ ../applications/obs-studio ];

  options.package.screen-capture.enable = lib.mkEnableOption "screen capture packages";

  config = lib.mkIf config.package.screen-capture.enable {
    home.packages = with pkgs; [
      grim
      slurp
    ];
  };
}
