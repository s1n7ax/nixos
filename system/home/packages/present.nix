{ pkgs, ... }:
{

  options.package.present.enable = lib.mkEnableOption "presentation tools";

  config = lib.mkIf config.package.present.enable {
    home.packages = with pkgs; [
      pkgs.slides
    ];
  };
}
