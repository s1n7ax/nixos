{
  lib,
  config,
  pkgs,
  ...
}:
{

  imports = [ ./obs-studio ];
  config = lib.mkIf config.features.productivity.video-production.screen-capture.enable {
    home.packages = with pkgs; [
      grim
      slurp
    ];
  };
}
