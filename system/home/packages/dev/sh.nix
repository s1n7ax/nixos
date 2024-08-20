{
  lib,
  config,
  pkgs,
  ...
}:
{

  options.package.dev.sh.enable = lib.mkEnableOption "sh/bash development environment";

  config = lib.mkIf config.package.dev.sh.enable { home.packages = with pkgs; [ shfmt ]; };
}
