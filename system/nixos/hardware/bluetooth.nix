{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.features.hardware.bluetooth;

  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];

  reconnect = pkgs.writeShellApplication {
    name = "bt-reconnect";
    runtimeInputs = [
      config.hardware.bluetooth.package
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
    ];
    text = builtins.readFile ./bluetooth/bt-reconnect.sh;
  };
in
{
  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.FastConnectable = true;
    };

    # BlueZ does not connect anything by itself after it starts or after a
    # resume, and a headset that is already on stops trying after a while.
    # Journal: `journalctl -b -u bluetooth-reconnect`.
    systemd.services.bluetooth-reconnect = mkIf cfg.reconnectAudio {
      description = "Reconnect paired Bluetooth audio devices";
      wantedBy = [ "bluetooth.service" ] ++ sleepTargets;
      after = [ "bluetooth.service" ] ++ sleepTargets;
      # A switch must not reconnect a headset the user just disconnected.
      restartIfChanged = false;
      serviceConfig.ExecStart = lib.getExe reconnect;
    };
  };
}
