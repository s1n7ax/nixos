{
  lib,
  pkgs,
  ...
}:
{
  options.package.web.enable = lib.mkEnableOption "web browser";
  imports = [ ../applications/firefox ];

  config.home.packages = with pkgs; [ chromium ];
}
