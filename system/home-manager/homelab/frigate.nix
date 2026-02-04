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
  storage_path = "${config.settings.storagePath}/.homelab/frigate";
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
      "d ${config.settings.storagePath}/.homelab 0700 - - -"
      "d ${config.settings.storagePath}/.homelab/frigate 0700 - - -"
      "d ${config.settings.storagePath}/.homelab/frigate/media 0700 - - -"
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
        # following is for google coral
        # "/dev/apex_0:/dev/apex_0"
        "/dev/dri/renderD128:/dev/dri/renderD128"
      ];

      # Volume mounts
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "${data_path}/config:/config/db:Z"
        "${storage_path}/media:/media/frigate:Z"
        "${model}:/data/models/model.tflite"
        "${model_label}:/data/models/labels.txt"
        "${config.sops.templates."frigate-config.yml".path}:/config/config.yaml:ro"
        "/home/s1n7ax/yolo_nas.onnx:/data/yolo_nas.onnx"
        "/home/s1n7ax/labels.txt:/data/labels.txt"
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

        auth:
          session_length: 2592000

        audio:
          enabled: true

        ffmpeg:
          hwaccel_args: preset-vaapi

        detectors:
          ov:
            type: openvino
            device: GPU

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
            - bus
            - truck
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
          model_type: yolonas
          width: 320
          height: 320
          input_tensor: nchw
          input_pixel_format: bgr
          path: /data/yolo_nas.onnx
          labelmap_path: /data/labels.txt

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
              - bus
              - truck
              - umbrella

        #--------------------------------------------------------------------#
        #                              SNAPSHOT                              #
        #--------------------------------------------------------------------#
        snapshots:
          enabled: true
          timestamp: true
          retain:
            default: 30 # Keep snapshots for 2 days

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

            objects:
              filters:
                car:
                  mask: 1,0.798,0.734,0.492,0.355,0.809,0.432,1,1,1
                motorcycle:
                  mask: 0.101,0.333,0.194,0.279,0.219,0.478,0.133,0.526
                    
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

            objects:
              filters:
                car:
                  mask: 0.002,0.74,0.26,0.228,0.471,0.245,0.598,0.368,0.466,1,0,1
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
