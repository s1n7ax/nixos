{
  lib,
  pkgs,
  config,
  ...
}:
{
  config = lib.mkIf config.features.development.c.enable {
    home.packages = with pkgs; [
      gcc
      gnumake
    ];
  };
}
