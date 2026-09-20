{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.cli.scripts.enable {
  home.packages = with pkgs; [
    (writeShellScriptBin "run-command-at" ''
      # just exit if the location is empty
      if [ -z "$2" ]; then
        exit 0;
      fi

      cd "$2";
      "$1";
    '')

    (writeShellScriptBin "pass-menu" ''
      record=$(
        fd \
          --extension 'gpg' \
          --type f \
          --base-directory ~/.password-store \
        | sd '.gpg' "" \
        | fzf
      )

      pass -c "$record"
    '')

    (writeShellScriptBin "project-menu" ''
      quick_exit ()
      {
        read VAR
        if [ ! -z "$VAR" ]; then
          echo $VAR
          PID=$$
          kill $PID 2&> /dev/null
        fi
      }

      fd -I -i -H \
        -t d ^.git$ ~/.config ~/Workspace \
        -x 'echo' '{//}' | fzf | quick_exit
    '')

    # converts all the possible video files in the current directory to a codec
    # that is supported by davinci resolve editor
    (writeShellScriptBin "davincify" ''
      set -euxo pipefail

      if [[ $# -eq 0 ]] ; then

        vid_files=$(fd \
          --absolute-path \
          --type file \
          --no-ignore \
          --exact-depth 1 \
          '.*.mov|.*.avi|.*.mkv' \
          .)

        if [[ $(echo $vid_files | wc -l) -lt 1 ]]; then
          echo "No files found of type mov, avi or mkv to encode"
          exit 1
        fi

        mkdir -p converted

        IFS=$'\n'
        for line in $vid_files
        do
          base_dir=$(dirname "$line")
          base_file=$(basename "$line")
          base_file_no_ext=$(echo "$base_file" | cut -f 1 -d '.')

          source="$line"
          target="$base_dir/converted/$base_file_no_ext.mov"

          echo "$base_file_no_ext"
          echo "$source"
          echo "$target"

          ffmpeg -i "$source" -c:v mjpeg -q:v 1 -c:a pcm_s16le -q:a 1 "$target" 2> /dev/null
        done

        exit 0
      fi
    '')

    (writeShellScriptBin "conv-mkv-to-mov" ''
      #!/bin/sh

      set -euxo pipefail

      if [[ $# -eq 0 ]] ; then
        # has no parameters
        echo 'Converting all the files in the current dir to mov'

        mov_files=$(fd -t f --no-ignore '.*\.mkv')

        if [ -n "$mov_files" ]; then
          mkdir -p "converted";
          
          echo "$mov_files" | 
          xargs -I {} basename {} .mkv | \
          xargs -I {} \
          sh -c 'ffmpeg -i "{}.mkv" -vcodec mjpeg -q:v 2 -acodec pcm_s16be -q:a 0 -f mov "converted/{}.mov"'
        fi

        exit 0
      else
        echo 'Converting "$1" to mov'

        abs_path=$(realpath "$1")

        if [ ! -f "$abs_path" ]; then
          echo "File not found"
          exit 1;
        fi

        mkdir -p "converted"
        target="$(dirname "$abs_path")/converted/$(basename "$abs_path")"

        ffmpeg -i "$abs_path" -vcodec mjpeg -q:v 2 -acodec pcm_s16be -q:a 0 -f mov "$target_path"

        exit 0
      fi
    '')

    (writeShellScriptBin "conv-mov-to-mp4" ''
      #!/bin/bash

      set -euxo pipefail

      if [[ $# -eq 0 ]] ; then
          echo 'Video file path should be passed to the command'
          exit 0
      fi

      ABSOLUTE_PATH=$(realpath "$1")
      FILE_PATH_WITHOUT_EXT="$\{ABSOLUTE_PATH%%.*}"

      TARGET_FILE="$FILE_PATH_WITHOUT_EXT.mp4"

      ffmpeg -i "$ABSOLUTE_PATH" -qscale 0 "$TARGET_FILE"
    '')

    (writeShellScriptBin "conv-webm-to-mp3" ''
      #!/bin/env bash

      for FILE in *.webm; do
          echo -e "Processing video '\e[32m$FILE\e[0m'";
          ffmpeg -i "$\{FILE}" -vn -ab 128k -ar 44100 -y "$\{FILE%.webm}.mp3";
      done;
    '')

    (writeShellScriptBin "kc-share" ''
      set -euxo pipefail

      if [[ $# -eq 0 ]]; then
        echo 'Path to share should be passed'
        exit 1
      fi

      SHARE_PATH=$(echo "$1" | sed 's/\\ / /g')

      function find_files {
        if [ -d "$SHARE_PATH" ]; then
          find "$SHARE_PATH" -type f
        else
          echo "$SHARE_PATH"
        fi
      }

      function get_device_names {
        echo "$(kdeconnect-cli --list-available --name-only)"
      }

      function get_device_count {
        echo "$(get_device_names)" | wc -l
      }

      # when the computer boots for the first time, device cannot connect.
      # I think this is due to the daemon not running
      # so following will make sure daemon is running
      count=5

      for i in $(seq $count); do
        echo "Looking for devices..."

        if [ $(get_device_count) -gt 0 ]; then
          break
        fi

        kdeconnect-cli --refresh

        # just waiting for few seconds so devices got time to connect to host
        sleep 2
      done

      if [ $(get_device_count) -eq 0 ]; then
        echo "Could not find a device to send files"
        exit 1
      fi

      if [ $(get_device_count) -gt 1 ]; then
        PICKED_DEVICE=$(echo "$(get_device_names)" | rofi -dmenu)
      else
        PICKED_DEVICE="$(get_device_names)"
      fi

      for path in "$@"; do
        find_files "$path" | xargs -I{} kdeconnect-cli --name="$PICKED_DEVICE" --share="{}"
      done
    '')

    (writeShellScriptBin "wofiw" ''
      wofi --show drun \
        --allow-images \
        --no-actions \
        --insensitive
    '')
    (writeShellApplication {
      name = "camera-connect";
      runtimeInputs = [
        coreutils
        ffmpeg
        gphoto2
        kmod
      ];
      text = ''
        node_nr=9
        node="/dev/video$node_nr"
        label=camera

        if ! gphoto2 --auto-detect | grep -q 'usb:'; then
          echo "No camera found. Turn the camera on, set movie mode, then plug in USB." >&2
          exit 1
        fi

        current_label=$(cat "/sys/devices/virtual/video4linux/video$node_nr/name" 2>/dev/null || true)

        if [ "$current_label" != "$label" ]; then
          if lsmod | grep -q '^v4l2loopback '; then
            if ! sudo modprobe -r v4l2loopback; then
              echo "v4l2loopback is loaded with the wrong options and something is still using it." >&2
              exit 1
            fi
          fi

          sudo modprobe v4l2loopback \
            exclusive_caps=1 \
            max_buffers=2 \
            video_nr="$node_nr" \
            card_label="$label"
        fi

        for _ in $(seq 1 50); do
          if [ -w "$node" ]; then
            break
          fi
          sleep 0.1
        done

        if [ ! -w "$node" ]; then
          echo "$node never became writable -- udev did not apply the video group." >&2
          exit 1
        fi

        gphoto2 --reset >/dev/null 2>&1 || true

        echo "Streaming the camera to $node. Press Ctrl-C to stop."

        gphoto2 \
          --stdout \
          --set-config viewfinder=1 \
          --capture-movie |
          ffmpeg \
            -i - \
            -vcodec copy \
            -threads 1 \
            -f v4l2 \
            "$node"
      '';
    })

    (writeShellScriptBin "font-menu" ''
      set -euo pipefail
      fc-list --format="%{family[0]}\n" | sort | uniq | fzf | tr -s \n | tr -s [:space:] | wl-copy
    '')

    (writeShellApplication {
      name = "img-rotate";
      runtimeInputs = [ imagemagick ];
      text = ''
        if [ $# -eq 0 ]; then
          echo "Usage: img-rotate <image>..." >&2
          exit 1
        fi

        magick mogrify -auto-orient -rotate 90 -orient TopLeft "$@"
      '';
    })

    (callPackage ./img-crop { })

    (writeShellApplication {
      name = "img-to-pdf";
      runtimeInputs = [ img2pdf ];
      text = ''
        if [ $# -eq 0 ]; then
          echo "Usage: img-to-pdf <image>..." >&2
          exit 1
        fi

        if [ -e output.pdf ]; then
          echo "output.pdf already exists in $PWD" >&2
          exit 1
        fi

        img2pdf --first-frame-only --output output.pdf -- "$@"
      '';
    })
  ];
}
