{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [ ./firefox ];
  config.home.packages = lib.mkIf config.features.web.enable [ pkgs.chromium ];
}
