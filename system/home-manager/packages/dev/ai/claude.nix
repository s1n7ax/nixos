{
  pkgs-unstable,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.features.development.ai.claude.enable {
    home.packages = [
      pkgs-unstable.claude-code
    ];
  };
}
