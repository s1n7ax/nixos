{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.java.enable = lib.mkEnableOption "java depelopment environment";

  config = lib.mkIf config.package.dev.java.enable {
    home.packages = with pkgs; [
      jdk21
      gradle
    ];
  };
}
