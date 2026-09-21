{
  lib,
  config,
  pkgs,
  ...
}:
let
  indicator = pkgs.callPackage ./screen-record/indicator { };

  /**
    Full-screen recorder with the camera composited into the bottom-right
    corner. gpu-screen-recorder itself is installed system-wide by
    `programs.gpu-screen-recorder`, which owns the setcap'd gsr-kms-server that
    monitor capture needs, so it is resolved from PATH instead of runtimeInputs.
  */
  screen-record = pkgs.writeShellApplication {
    name = "screen-record";
    runtimeInputs = [
      indicator
      pkgs.coreutils
      pkgs.gawk
      pkgs.jq
      pkgs.libnotify
    ];
    text = builtins.readFile ./screen-record/record.sh;
  };
in
{
  config = lib.mkIf config.features.productivity.video-production.screen-capture.enable {
    home.packages = [
      screen-record
      indicator
    ];
  };
}
