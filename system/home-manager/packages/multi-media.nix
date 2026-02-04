{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.multimedia.enable {
    home.packages = with pkgs; [
      digikam
      gimp
      handbrake
      # kdePackages.kdenlive
    ];
  };
}
