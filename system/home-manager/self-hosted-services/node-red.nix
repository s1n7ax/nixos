{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  # Node-RED's home-assistant-websocket nodes snapshot HA's entity registry on
  # connect. If Node-RED starts while HA is still booting its integrations, that
  # snapshot is incomplete. Block startup until HA's HTTP API answers (on its
  # published host port), bounded so Node-RED always starts eventually — worst
  # case is the pre-existing behaviour, never worse.
  waitForHomeAssistant = pkgs.writeShellScript "wait-for-home-assistant" ''
    end=$(( SECONDS + 300 ))
    while [ "$SECONDS" -lt "$end" ]; do
      ${pkgs.curl}/bin/curl -fsS -m 5 http://127.0.0.1:8124/ >/dev/null 2>&1 && exit 0
      ${pkgs.coreutils}/bin/sleep 5
    done
    exit 0
  '';
in
{
  config = mkIf config.features.homelab.node-red.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/node-red 0750 - - -"
    ];

    services.podman.containers.node-red = {
      image = "nodered/node-red:latest";
      network = [
        "home-assistant-network"
        "mqtt-network"
      ];
      ports = [
        "1880:1880"
      ];
      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];
      volumes = [
        "${config.home.homeDirectory}/.homelab/node-red:/data:Z"
      ];
      autoStart = true;

      # Wait for Home Assistant to be reachable before starting (only when HA is
      # actually enabled). TimeoutStartSec must exceed the wait ceiling above, or
      # systemd would kill the start as timed out while ExecStartPre polls.
      extraConfig = mkIf config.features.homelab.home-assistant.enable {
        Unit.After = [ "podman-home-assistant.service" ];
        Service = {
          ExecStartPre = "${waitForHomeAssistant}";
          TimeoutStartSec = 360;
        };
      };
    };
  };
}
