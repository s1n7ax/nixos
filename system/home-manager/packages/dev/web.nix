{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.web.enable {
    home.packages = with pkgs; [
      jq
      httpie
      bruno
      dart-sass
    ];
  };
}
