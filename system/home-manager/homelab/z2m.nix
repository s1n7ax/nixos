{
  config,
  lib,
  ...
}:
let
  data_path = "${config.home.homeDirectory}/.homelab/z2m";
  network_key = config.sops.placeholder."z2m/network_key";
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
      image = "ghcr.io/koenkk/zigbee2mqtt";
      network = [
        "mqtt-network"
        "z2m-network"
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

    home.file."${data_path}/configuration.yaml".text = ''
      version: 4
      mqtt:
        base_topic: zigbee2mqtt
        server: mqtt://mqtt:1883
      serial:
        port: tcp://192.168.1.100:6638
        baudrate: 115200
        adapter: zstack
        disable_led: false
      advanced:
        log_level: info
        channel: 25
        transmit_power: 20
        network_key: '!/app/secrets/secret.yaml network_key'
        pan_id: 26823
        ext_pan_id:
          - 242
          - 246
          - 94
          - 150
          - 77
          - 76
          - 67
          - 57
      frontend:
        enabled: true
        port: 8080
      homeassistant:
        enabled: true
      devices: devices.yaml
    '';
  };
}
