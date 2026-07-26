{
  pkgs-unstable,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.features.development.ai.cursor-cli.enable {
    home.packages = [ pkgs-unstable.cursor-cli ];
  };
}
