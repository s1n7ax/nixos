{
  config,
  lib,
  pkgs,
  ...
}:
let
  data_path = "${config.home.homeDirectory}/.homelab/z2m";
  network_key = config.sops.placeholder."z2m/network_key";
  permit_join_forever = pkgs.writeText "permit_join_forever.js" ''
    /**
     * This extension is NOT recommended but unfortunately necessary
     * for some devices to work properly (like Livolo). Use with caution
     * as this will make it very easy for someone to hack your Zigbee network!
     * https://github.com/Koenkk/zigbee2mqtt/issues/25626
     *
     * Joining is renewed with the same mode it was last opened with ("All"
     * or via a specific router), and only while it is still open, so a
     * manual disable from the frontend sticks.
     */
    const NS = 'ext:permit-join-forever';

    class PermitJoinForeverExtension {
        constructor(zigbee, mqtt, state, publishEntityState, eventBus, enableDisableExtension, restartCallback, addExtension, settings, logger) {
            this.logger = logger;
            this.zigbee = zigbee;
            this.device = undefined;
        }

        start() {
            this.logger.warning('Permitting joining forever, only use this extension when strictly necessary!', NS);

            // herdsman does not remember which router joining was opened
            // through, so record it from every permitJoin call (frontend, MQTT)
            const permitJoin = this.zigbee.permitJoin;
            this.zigbee.permitJoin = async (time, device) => {
                this.device = time > 0 ? device : undefined;
                return permitJoin.call(this.zigbee, time, device);
            };

            this.zigbee.permitJoin(254);
            this.interval = setInterval(async () => {
                if (!this.zigbee.getPermitJoin()) {
                    return;
                }

                try {
                    await this.zigbee.permitJoin(254, this.device);
                } catch (error) {
                    this.logger.error('Failed to renew permit join: ' + error.message, NS);
                }
            }, 240 * 1000);
        }

        stop() {
            clearInterval(this.interval);
            delete this.zigbee.permitJoin;
        }
    }

    module.exports = PermitJoinForeverExtension;
  '';
in
with lib;
{
  config = mkIf config.features.homelab.z2m.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/z2m 0700 - - -"
    ];

    services.podman.networks.z2m-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.z2m = {
      image = "ghcr.io/koenkk/zigbee2mqtt:latest";
      autoUpdate = "registry";
      network = [
        "mqtt-network"
        "z2m-network"
      ];
      extraPodmanArgs = [
        "--group-add=keep-groups"
        "--tz=local"
      ];
      volumes = [
        "${data_path}:/app/data"
        "${data_path}/configuration.yaml:/app/data/configuration.yaml"
        "${config.sops.templates."secret.yaml".path}:/app/secrets/secret.yaml"
        "/run/udev:/run/udev:ro"
      ];
      ports = [ "8080:8080" ];
    };

    sops.templates."secret.yaml" = {
      content = ''
        network_key: ${network_key}
      '';
    };

    home.activation.z2mExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${data_path}/external_extensions
      $DRY_RUN_CMD cp -f ${permit_join_forever} ${data_path}/external_extensions/permit_join_forever.js
    '';

    home.file."${data_path}/configuration.yaml".text = ''
      version: 5
      mqtt:
        base_topic: zigbee2mqtt
        server: mqtt://mqtt:1883
      serial:
        port: tcp://192.168.1.170:6638
        baudrate: 115200
        adapter: ember
        rtscts: false
      advanced:
        log_level: info
        channel: 25
        transmit_power: 20
        last_seen: ISO_8601
        network_key: '!/app/secrets/secret.yaml network_key'
        pan_id: 27259
        ext_pan_id: [200, 189, 37, 39, 41, 120, 164, 152]
      availability:
        enabled: true
        active:
          timeout: 10
        passive:
          timeout: 1500
      frontend:
        enabled: true
        port: 8080
      homeassistant:
        enabled: true
      devices: devices.yaml
    '';
  };
}
