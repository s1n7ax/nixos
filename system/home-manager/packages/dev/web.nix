{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.web.enable = lib.mkEnableOption "web development environment";

  config = lib.mkIf config.package.dev.web.enable {
    home.packages = with pkgs; [
      jq
      httpie
      dart-sass
    ];
  };
}
