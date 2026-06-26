{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.multimedia.gaming.enable {
    home.packages = with pkgs; [ steam ];
  };
}
