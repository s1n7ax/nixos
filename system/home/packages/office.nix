{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.package.office.enable = lib.mkEnableOption "office packages";

  config = lib.mkIf config.package.office.enable {
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "slack"
        "teams"
      ];

    home.packages =
      with pkgs;
      [
      ];
  };
}
