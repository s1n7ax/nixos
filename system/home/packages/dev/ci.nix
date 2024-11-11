{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.package.dev.ci.enable = lib.mkEnableOption "ci/cd environment";

  config = lib.mkIf config.package.dev.ci.enable {
    home.packages = with pkgs; [
      act
    ];
  };

}
