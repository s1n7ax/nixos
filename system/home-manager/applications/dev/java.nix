{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.java.enable {
    home.packages = with pkgs; [
      jdk21
      gradle
    ];
  };
}
