{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.gaming.enable = lib.mkEnableOption "gaming related packages";

  config = lib.mkIf config.package.gaming.enable { home.packages = with pkgs; [ steam ]; };
}
