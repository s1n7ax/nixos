{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.hardware.bluetooth.enable {
    xdg.desktopEntries.bluetui = {
      name = "BlueTUI";
      exec = "${pkgs.bluetui}/bin/bluetui";
      terminal = true;
      type = "Application";
      categories = [
        "Settings"
        "HardwareSettings"
      ];
    };
  };
}
