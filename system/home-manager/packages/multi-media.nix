{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.multi-media.enable = lib.mkEnableOption "multi-media packages";

  config = lib.mkIf config.package.multi-media.enable {
    home.packages = with pkgs; [
      gimp
      handbrake
    ];
  };

}
