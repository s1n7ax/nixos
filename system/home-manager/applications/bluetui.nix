{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.hardware.bluetooth.enable {
    home.packages = with pkgs; [
      bluetui
    ];
  };
}
