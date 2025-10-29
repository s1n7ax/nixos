{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.ai.codex.enable {
    home.packages = with pkgs; [
      codex
    ];
  };
}
