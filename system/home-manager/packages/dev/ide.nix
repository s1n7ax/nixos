{
  lib,
  config,
  pkgs,
  ...
}:
{
  # imports = [ ../../applications/zed/zed.nix ];

  options.package.dev.ide.enable = lib.mkEnableOption "IDEs";

  config = lib.mkIf config.package.dev.ide.enable {
    home.packages = with pkgs; [
      vscode
    ];
  };
}
