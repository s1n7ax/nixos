{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib;

{
  config = mkIf config.features.development.ai.enable {
    home.packages =
      with pkgs;
      [ ]
      ++ optionals config.features.development.ai.claude.enable [
        pkgs-unstable.claude-code
      ];
  };
}
