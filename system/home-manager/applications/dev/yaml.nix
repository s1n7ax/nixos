{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.yaml.enable {
    home.packages = with pkgs; [ yaml-language-server ];
  };
}
