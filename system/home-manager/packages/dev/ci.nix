{
  lib,
  pkgs,
  config,
  ...
}:
{
  config = lib.mkIf config.features.development.ci.enable {
    home.packages = with pkgs; [
      act
    ];
  };
}
