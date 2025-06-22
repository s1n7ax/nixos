{
  config,
  lib,
  pkgs,
  ...
}:
let
  front_road = config.sops.placeholder."frigate/front_road/pass";
  front_car = config.sops.placeholder."frigate/front_car/pass";
  backyard_roof = config.sops.placeholder."frigate/backyard_roof/pass";
  backyard_shower = config.sops.placeholder."frigate/backyard_shower/pass";

  data_path = "${config.home.homeDirectory}/.homelab/frigate";
  model = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google-coral/test_data/master/efficientdet_lite3_512_ptq_edgetpu.tflite";
    sha256 = "sha256-T5jwmHJATZ4odE0/9pTYQnqWjdtGeprsCshhvZ89uhQ=";
  };
  model_label = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google-coral/test_data/master/coco_labels.txt";
    sha256 = "sha256-3Bg/AD/HU8TEP65v3384dVlElXPxP6MuUX+3RT/TgPE=";
  };
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

      network = [
        "frigate-network"
        "mqtt-network"
      ];

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
        "${model}:/data/models/model.tflite"
        "${model_label}:/data/models/labels.txt"
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
        version: 0.15-1

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

        #--------------------------------------------------------------------#
        #                              OBJECTS                               #
        #--------------------------------------------------------------------#
        objects:
          track:
            - person
            - bicycle
            - car
            - motorcycle
            - airplane
            - bus
            - train
            - truck
            - boat
            - umbrella
          filters:
            person:
              threshold: 0.6

        #--------------------------------------------------------------------#
        #                               MOTION                               #
        #--------------------------------------------------------------------#
        motion:
          mask: 0,0.103,0.297,0.103,0.3,0,0,0
          threshold: 30
          contour_area: 10
          improve_contrast: true

        #--------------------------------------------------------------------#
        #                               MODEL                                #
        #--------------------------------------------------------------------#
        model:
          path: /data/models/model.tflite
          labelmap_path: /data/models/labels.txt
          width: 512
          height: 512

        #--------------------------------------------------------------------#
        #                               DETECT                               #
        #--------------------------------------------------------------------#
        detect:
          enabled: true
          width: 640
          height: 360
          fps: 5

        #--------------------------------------------------------------------#
        #                               REVIEW                               #
        #--------------------------------------------------------------------#
        review:
          alerts:
            labels:
              - person
              - bicycle
              - car
              - motorcycle
              - airplane
              - bus
              - train
              - truck
              - boat
              - umbrella

        #--------------------------------------------------------------------#
        #                              SNAPSHOT                              #
        #--------------------------------------------------------------------#
        snapshots:
          enabled: true
          timestamp: true
          retain:
            default: 2 # Keep snapshots for 2 days

        #--------------------------------------------------------------------#
        #                               RECORD                               #
        #--------------------------------------------------------------------#
        record:
          enabled: true
          retain:
            days: 2
          alerts:
            retain:
              days: 10

        semantic_search:
          enabled: true
          reindex: false
          model_size: large

        cameras:
          #--------------------------------------------------------------------#
          #                                ROAD                                #
          #--------------------------------------------------------------------#
          front_road:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${front_road}@192.168.1.124:554/Streaming/Channels/101/
                  roles: [record]
                - path: rtsp://viewer:${front_road}@192.168.1.124:554/Streaming/Channels/102/
                  roles: [detect, audio]
                    
          #--------------------------------------------------------------------#
          #                                CAR                                 #
          #--------------------------------------------------------------------#
          front_car:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${front_car}@192.168.1.123:554/Streaming/Channels/101/
                  roles: [record]
                - path: rtsp://viewer:${front_car}@192.168.1.123:554/Streaming/Channels/102/
                  roles: [detect, audio]

          #--------------------------------------------------------------------#
          #                                ROOF                                #
          #--------------------------------------------------------------------#
          backyard_roof:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${backyard_roof}@192.168.1.122:554/Streaming/Channels/101/
                  roles: [record]
                - path: rtsp://viewer:${backyard_roof}@192.168.1.122:554/Streaming/Channels/102/
                  roles: [detect, audio]

          #--------------------------------------------------------------------#
          #                               SHOWER                               #
          #--------------------------------------------------------------------#
          backyard_shower:
            ffmpeg:
              inputs:
                - path: rtsp://viewer:${backyard_shower}@192.168.1.121:554/Streaming/Channels/101/
                  roles: [record]
                - path: rtsp://viewer:${backyard_shower}@192.168.1.121:554/Streaming/Channels/102/
                  roles: [detect, audio]
      '';
    };
  };
}
