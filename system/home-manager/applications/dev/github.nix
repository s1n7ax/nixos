{
  lib,
  pkgs,
  config,
  ...
}:
{
  config = lib.mkIf config.features.development.github.enable {
    home.packages = with pkgs; [
      gh
    ];
  };
}
