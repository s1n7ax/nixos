{
  lib,
  ...
}:
{
  options.package.web.enable = lib.mkEnableOption "web browser";
  imports = [ ../applications/firefox ];
}
