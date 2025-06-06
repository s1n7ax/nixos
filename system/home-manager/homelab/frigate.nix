{ config, lib, ... }:
let
  front_road = config.sops.placeholder."frigate/front_road/pass";
  front_car = config.sops.placeholder."frigate/front_car/pass";
  backyard_roof = config.sops.placeholder."frigate/backyard_roof/pass";
  backyard_shower = config.sops.placeholder."frigate/backyard_shower/pass";

  data_path = "${config.home.homeDirectory}/.homelab/frigate";
in
with lib;
{
  config = mkIf config.features.homelab.frigate.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/frigate 0700 - - -"
      "d %h/.homelab/frigate/media 0700 - - -"
      "d %h/.homelab/frigate/config 0700 - - -"
    ];

    services.podman.networks.frigate-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.frigate = {
      image = "ghcr.io/blakeblackshear/frigate:stable";

      network = [ "frigate-network" ];

      ports = [
        "8971:8971"
        "8554:8554"
        "8555:8555/tcp"
        "8555:8555/udp"
      ];

      devices = [
        "/dev/apex_0:/dev/apex_0"
        "/dev/dri/renderD128:/dev/dri/renderD128"
      ];

      # Volume mounts
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "${data_path}/config:/config/db:Z"
        "${data_path}/media:/media/frigate:Z"
        "${config.sops.templates."frigate-config.yml".path}:/config/config.yaml:ro"
      ];

      environment = {
        TZ = "Asia/Colombo";
      };

      extraPodmanArgs = [
        "--shm-size=1024m"
        "--mount=type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000"
        "--group-add=keep-groups"
      ];
      autoStart = true;
    };

    sops.templates."frigate-config.yml" = {
      content = ''
        mqtt:
          enabled: true
          host: mqtt

        tls:
          enabled: false

        audio:
          enabled: true

        ffmpeg:
          hwaccel_args: preset-vaapi

        detectors:
          coral:
            type: edgetpu
            device: pci

        database:
          path: /config/db/frigate.db

        objects:
          track:
            - person

        cameras:
          front_road:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${front_road}@192.168.1.124:554/Streaming/Channels/101/
                  roles:
                    - record
                - path: rtsp://viewer:${front_road}@192.168.1.124:554/Streaming/Channels/102/
                  roles:
                    - detect
                    - audio

            objects:
              track:
                - person
                - hat
                - umbrella
              filters:
                person:
                  threshold: 0.6

            detect:
              enabled: true
              width: 640
              height: 360
              fps: 6

            review:
              alerts:
                labels:
                  - person
                  - hat
                  - umbrella

            snapshots:
              enabled: true
              timestamp: true
              retain:
                default: 2 # Keep snapshots for 2 days

            record:
              enabled: true
              retain:
                days: 2
              alerts:
                retain:
                  days: 10
                # mode: motion # Only save motion-based recordings

            motion:
              mask: 0,0.103,0.297,0.103,0.3,0,0,0
              threshold: 30
              contour_area: 10
              improve_contrast: true

          front_car:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${front_car}@192.168.1.123:554/Streaming/Channels/101/
                  roles:
                    - record
                - path: rtsp://viewer:${front_car}@192.168.1.123:554/Streaming/Channels/102/
                  roles:
                    - detect
                    - audio

            objects:
              track:
                - person
                - hat
                - umbrella
              filters:
                person:
                  threshold: 0.6

            detect:
              enabled: true
              width: 640
              height: 360
              fps: 6

            review:
              alerts:
                labels:
                  - person
                  - hat
                  - umbrella

            snapshots:
              enabled: true
              timestamp: true
              retain:
                default: 2 # Keep snapshots for 2 days

            record:
              enabled: true
              retain:
                days: 2
              alerts:
                retain:
                  days: 10
                # mode: motion # Only save motion-based recordings

            motion:
              mask: 0,0.103,0.297,0.103,0.3,0,0,0
              threshold: 30
              contour_area: 10
              improve_contrast: true

          backyard_roof:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${backyard_roof}@192.168.1.122:554/Streaming/Channels/101/
                  roles:
                    - record
                - path: rtsp://viewer:${backyard_roof}@192.168.1.122:554/Streaming/Channels/102/
                  roles:
                    - detect
                    - audio

            objects:
              track:
                - person
                - hat
                - umbrella
              filters:
                person:
                  threshold: 0.6

            detect:
              enabled: true
              width: 640
              height: 360
              fps: 6

            review:
              alerts:
                labels:
                  - person
                  - hat
                  - umbrella

            snapshots:
              enabled: true
              timestamp: true
              retain:
                default: 2 # Keep snapshots for 2 days

            record:
              enabled: true
              retain:
                days: 2
              alerts:
                retain:
                  days: 10
                # mode: motion # Only save motion-based recordings

            motion:
              mask: 0,0.103,0.297,0.103,0.3,0,0,0
              threshold: 30
              contour_area: 10
              improve_contrast: true

          backyard_shower:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${backyard_shower}@192.168.1.121:554/Streaming/Channels/101/
                  roles:
                    - record
                - path: rtsp://viewer:${backyard_shower}@192.168.1.121:554/Streaming/Channels/102/
                  roles:
                    - detect
                    - audio

            objects:
              track:
                - person
                - hat
                - umbrella
              filters:
                person:
                  threshold: 0.6

            detect:
              enabled: true
              width: 640
              height: 360
              fps: 6

            review:
              alerts:
                labels:
                  - person
                  - hat
                  - umbrella

            snapshots:
              enabled: true
              timestamp: true
              retain:
                default: 2 # Keep snapshots for 2 days

            record:
              enabled: true
              retain:
                days: 2
              alerts:
                retain:
                  days: 10
                # mode: motion # Only save motion-based recordings

            motion:
              mask: 0,0.103,0.297,0.103,0.3,0,0,0
              threshold: 30
              contour_area: 10
              improve_contrast: true
        motion:
          threshold: 25
          contour_area: 100
        version: 0.15-1
        semantic_search:
          enabled: true
          reindex: false
          model_size: large
      '';
    };
  };
}
