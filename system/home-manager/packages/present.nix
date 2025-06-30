{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../applications/presenterm/default.nix
  ];

  config = lib.mkIf config.features.presentation.enable {
    home.packages = with pkgs; [
      marp-cli
    ];
  };
}
