{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.database.enable {
    home.packages = with pkgs; [
      pgformatter
      postgresql
      sqlite
      sqlfluff
    ];
  };
}
