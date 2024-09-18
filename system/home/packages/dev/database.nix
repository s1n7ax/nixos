{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.database.enable = lib.mkEnableOption "database environment";

  config = lib.mkIf config.package.dev.database.enable {
    home.packages = with pkgs; [
      postgresql
      sqlite
      sqlfluff
    ];
  };
}
