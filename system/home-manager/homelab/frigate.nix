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
    sops.secrets."frigate/plus/api_key" = { };

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
      image = "ghcr.io/blakeblackshear/frigate:0.17.1";

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
        "${data_path}/config:/config/db:Z"
        "${storage_path}/media:/media/frigate:Z"
        "${model}:/data/models/model.tflite"
        "${model_label}:/data/models/labels.txt"
        "${config.sops.templates."frigate-config.yml".path}:/config/config.yaml:ro"
        # "/home/s1n7ax/yolo_nas.onnx:/data/yolo_nas.onnx"
        # "/home/s1n7ax/labels.txt:/data/labels.txt"
      ];

      extraPodmanArgs = [
        "--tz=local"
        "--shm-size=1024m"
        "--mount=type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000"
        "--group-add=keep-groups"
        "--env-file=${config.sops.templates."frigate.env".path}"
      ];
      autoStart = true;
    };

    sops.templates."frigate.env" = {
      content = ''
        PLUS_API_KEY=${config.sops.placeholder."frigate/plus/api_key"}
      '';
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
            - car
            - motorcycle
            - umbrella
          filters:
            all:
              min_score: 0.3
              threshold: 0.4

        #--------------------------------------------------------------------#
        #                               MOTION                               #
        #--------------------------------------------------------------------#
        motion:
          mask:
            - 0,0.103,0.297,0.103,0.3,0,0,0
            - 0.719,0.889,0.839,0.89,0.839,0.929,0.72,0.929
          threshold: 30
          contour_area: 10
          improve_contrast: true

        #--------------------------------------------------------------------#
        #                               MODEL                                #
        #--------------------------------------------------------------------#
        model:
          path: plus://062ae1e0ab694333027353df0d4eb982
          # Relabel bicycle as motorcycle, and merge every other vehicle
          # (motorcycle, airplane, bus, train, truck, boat) into car.
          # COCO indices: 1=bicycle, 3=motorcycle, 4=airplane, 5=bus,
          # 6=train, 7=truck, 8=boat.
          labelmap:
            1: motorcycle
            3: car
            4: car
            5: car
            6: car
            7: car
            8: car

        #--------------------------------------------------------------------#
        #                               DETECT                               #
        #--------------------------------------------------------------------#
        detect:
          enabled: true
          width: 640
          height: 360
          fps: 6

        #--------------------------------------------------------------------#
        #                               REVIEW                               #
        #--------------------------------------------------------------------#
        review:
          alerts:
            labels:
              - person
              - car
              - motorcycle
              - umbrella

        #--------------------------------------------------------------------#
        #                              SNAPSHOT                              #
        #--------------------------------------------------------------------#
        snapshots:
          enabled: true
          timestamp: true
          retain:
            default: 90

        #--------------------------------------------------------------------#
        #                               RECORD                               #
        #--------------------------------------------------------------------#
        record:
          enabled: true
          continuous:
            days: 30
          detections:
            retain:
              days: 60
          alerts:
            retain:
              days: 60

        semantic_search:
          enabled: true
          reindex: false
          model_size: large

        face_recognition:
          enabled: true
          model_size: large

        cameras:
          #--------------------------------------------------------------------#
          #                                ROAD                                #
          #--------------------------------------------------------------------#
          front_road:
            lpr:
              enabled: true
            motion:
              threshold: 40
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
            motion:
              threshold: 40
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
            motion:
              threshold: 35
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
            motion:
              threshold: 35
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
