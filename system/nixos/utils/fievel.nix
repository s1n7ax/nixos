{ config, lib, ... }:
let
  username = config.settings.username;
in
{
  # fievel (home-manager service) grabs the keyboards under /dev/input and
  # creates its virtual keyboard and pointer through /dev/uinput.
  config = lib.mkIf config.features.desktop.fievel.enable {
    hardware.uinput.enable = true;

    users.users.${username}.extraGroups = [
      "input"
      "uinput"
    ];
  };
}
