{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.toml.enable { home.packages = with pkgs; [ taplo ]; };
}
