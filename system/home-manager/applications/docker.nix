{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.virtualization.docker;
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.docker-cli.enable = lib.mkIf pkgs.stdenv.isDarwin true;
      }
      (lib.mkIf pkgs.stdenv.isDarwin {
        services.colima.enable = true;
        home.packages = [ pkgs.docker ];
      })
    ]
  );
}
