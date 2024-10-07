{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.ide.enable = lib.mkEnableOption "IDEs";

  config = lib.mkIf config.package.dev.ide.enable {
    home.packages = [
      pkgs.vscode
    ];
  };
}
