{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [ ../applications/firefox ];
  config.home.packages = lib.mkIf config.features.web.enable [ pkgs.chromium ];
}
