{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.toml.enable = lib.mkEnableOption "toml development environment";

  config = lib.mkIf config.package.dev.toml.enable { home.packages = with pkgs; [ taplo ]; };
}
