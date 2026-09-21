{
  lib,
  config,
  pkgs,
  ...
}:
{

  imports = [
    ./obs-studio
    ./screen-record.nix
  ];
  config = lib.mkIf config.features.productivity.video-production.screen-capture.enable {
    home.packages = with pkgs; [
      grim
      slurp
    ];
  };
}
