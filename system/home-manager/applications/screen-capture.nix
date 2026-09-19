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

      # one take of screen + Canon R5 + both audio sources, into one file
      (callPackage ./record { })
    ];
  };
}
