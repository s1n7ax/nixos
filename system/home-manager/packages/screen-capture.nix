{
  lib,
  config,
  pkgs,
  ...
}:
{

  imports = [ ../applications/obs-studio ];
  config = lib.mkIf config.features.productivity.video-production.screen-capture.enable {
    home.packages = with pkgs; [
      grim
      slurp
    ];
  };
}
