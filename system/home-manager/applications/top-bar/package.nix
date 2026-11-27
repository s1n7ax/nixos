/**
  The top bar's Bluetooth and Wi-Fi menus (bluetooth-menu.sh, wifi-menu.sh),
  rofi pick lists like the power-profile menu.
*/
{
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  bluez,
  networkmanager,
  libnotify,
  rofi,
}:
{
  bluetooth-menu = writeShellApplication {
    name = "bluetooth-menu";
    runtimeInputs = [
      coreutils
      gnugrep
      bluez
      libnotify
      rofi
    ];
    text = builtins.readFile ./bluetooth-menu.sh;
  };

  wifi-menu = writeShellApplication {
    name = "wifi-menu";
    runtimeInputs = [
      coreutils
      gawk
      gnugrep
      gnused
      networkmanager
      libnotify
      rofi
    ];
    text = builtins.readFile ./wifi-menu.sh;
  };
}
