{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.ide.enable {
    home.packages = with pkgs; [
      vscode
    ];
  };
}
