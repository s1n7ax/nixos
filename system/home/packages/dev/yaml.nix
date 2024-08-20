{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.yaml.enable = lib.mkEnableOption "yaml environment";

  config = lib.mkIf config.package.dev.yaml.enable {
    home.packages = with pkgs; [ yaml-language-server ];
  };
}
