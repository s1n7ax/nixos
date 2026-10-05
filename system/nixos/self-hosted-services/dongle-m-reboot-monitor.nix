{
  config,
  lib,
  pkgs,
  ...
}:
# Records every reboot of the SONOFF Dongle-M Zigbee coordinator (time, and
# planned or unplanned from the dongle's own notification history) and sends
# a Home Assistant notification for each one. Tracks issue #168.
#
# Records: /var/lib/dongle-m-reboot-monitor/reboots.jsonl, one JSON object
# per reboot. Journal: `journalctl -u dongle-m-reboot-monitor`.
let
  username = config.settings.username;

  host = "192.168.1.170";
  # Home Assistant runs as a rootless podman container publishing 8124.
  haUrl = "http://127.0.0.1:8124";
  notify = "mobile_app_pixel_9_pro_xl";

  passwordSecret = "dongle-m/password";
  # Reuses the long-lived access token the Home Assistant MCP server uses;
  # point this at a dedicated token once one is in the secrets flake.
  haTokenSecret = "home-assistant/mcp_token";

  stateDir = "dongle-m-reboot-monitor";

  monitor = pkgs.writers.writePython3 "dongle-m-reboot-monitor" {
    libraries = [ pkgs.python3Packages.websockets ];
  } (builtins.readFile ./dongle-m-reboot-monitor/monitor.py);
in
with lib;
{
  config = mkIf config.features.homelab.dongle-m-reboot-monitor.enable {
    sops.secrets.${passwordSecret}.restartUnits = [ "dongle-m-reboot-monitor.service" ];
    sops.secrets.${haTokenSecret}.restartUnits = [ "dongle-m-reboot-monitor.service" ];

    systemd.services.dongle-m-reboot-monitor = {
      description = "SONOFF Dongle-M reboot monitor";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # Keep coming back; the monitor itself retries a missing dongle or
      # Home Assistant, so a restart only follows a bug.
      startLimitIntervalSec = 0;

      serviceConfig = {
        ExecStart = concatStringsSep " " [
          "${monitor}"
          "--host ${host}"
          "--state-dir /var/lib/${stateDir}"
          "--password-file %d/dongle-password"
          "--ha-url ${haUrl}"
          "--ha-token-file %d/ha-token"
          "--notify ${notify}"
        ];
        Restart = "always";
        RestartSec = 10;

        # The secrets stay root-only; systemd hands the service a private copy.
        LoadCredential = [
          "dongle-password:${config.sops.secrets.${passwordSecret}.path}"
          "ha-token:${config.sops.secrets.${haTokenSecret}.path}"
        ];

        # Runs as the main user so the records can be read without sudo.
        User = username;
        StateDirectory = stateDir;
        StateDirectoryMode = "0750";
        UMask = "0027";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
