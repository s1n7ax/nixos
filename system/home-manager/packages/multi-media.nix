{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.multimedia.enable {
    home.packages = with pkgs; [
      gimp
      handbrake
      kdePackages.kdenlive
    ];
  };
}
