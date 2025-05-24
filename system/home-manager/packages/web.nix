{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.package.web.enable = lib.mkEnableOption "web browser";
  imports = [ ../applications/firefox ];
  config.home.packages = lib.mkIf config.package.web.enable [ pkgs.chromium ];
}
