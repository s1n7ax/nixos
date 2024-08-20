{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.package.dev.c.enable = lib.mkEnableOption "c/c++ development environment";

  config = lib.mkIf config.package.dev.c.enable {
    home.packages = with pkgs; [
      gcc
      gnumake
    ];
  };

}
