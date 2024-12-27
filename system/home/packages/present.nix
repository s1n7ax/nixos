{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.package.present.enable = lib.mkEnableOption "presentation tools";

  imports = [
    ../applications/presenterm/default.nix
  ];

  config = lib.mkIf config.package.present.enable {
    home.packages = with pkgs; [
      marp-cli
    ];
  };
}
