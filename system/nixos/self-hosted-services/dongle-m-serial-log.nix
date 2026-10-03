{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
# Logs the SONOFF Dongle-M Zigbee coordinator's serial console (USB-C, a
# CP2102N wired to ESP32 UART0) so the ESP32 boot ROM reset reason
# ("rst:0x.. (REASON)") of every reboot is kept. Tracks issue #168.
let
  username = config.settings.username;

  # Matched on the USB IDs alone: the dongle's product and serial strings are
  # not known yet. Any other CP210x adapter plugged into this host matches too.
  vendorId = "10c4";
  productId = "ea60";

  device = "/dev/dongle-m";
  deviceUnit = "${utils.escapeSystemdPath device}.device";
  logDir = "dongle-m-serial";

  serialLog = pkgs.writers.writePython3 "dongle-m-serial-log" { } (
    builtins.readFile ./dongle-m-serial-log/serial-log.py
  );
in
with lib;
{
  config = mkIf config.features.homelab.dongle-m-serial-log.enable {
    # ModemManager is on here; keep it off the dongle, since its probe writes
    # AT commands to new serial ports and can toggle DTR/RTS (= reset the ESP32).
    # The tty rule adds /dev/dongle-m and has udev start the logger on plug-in.
    services.udev.extraRules = ''
      ATTRS{idVendor}=="${vendorId}", ATTRS{idProduct}=="${productId}", ENV{ID_MM_DEVICE_IGNORE}="1"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="${vendorId}", ATTRS{idProduct}=="${productId}", SYMLINK+="dongle-m", TAG+="systemd", ENV{SYSTEMD_WANTS}+="dongle-m-serial-log.service"
    '';

    systemd.services.dongle-m-serial-log = {
      description = "SONOFF Dongle-M serial console logger";
      # Only udev starts it, when the dongle appears; BindsTo stops it when the
      # dongle goes. With no wantedBy, a missing dongle never fails a boot or
      # an activation.
      bindsTo = [ deviceUnit ];
      after = [ deviceUnit ];
      # Keep starting on every replug, however often the dongle drops off USB.
      startLimitIntervalSec = 0;

      serviceConfig = {
        ExecStart = "${serialLog} ${device} /var/log/${logDir}";
        Restart = "always";
        RestartSec = 2;

        # Runs as the main user (already in dialout) so the log can be read
        # without sudo.
        User = username;
        SupplementaryGroups = [ "dialout" ];
        LogsDirectory = logDir;
        LogsDirectoryMode = "0750";
        UMask = "0027";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateNetwork = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [ "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
