{ pkgs, ... }:
{
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
        PICKED_DEVICE=$(echo "$(get_device_names)" | wofi --dmenu)
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
    (writeShellScriptBin "camera-connect" ''
      set -euo pipefail

      sudo modprobe v4l2loopback exclusive_caps=1 max_buffer=2

      gphoto2 \
      	--stdout \
      	--set-config viewfinder=1 \
      	--capture-movie |
      	ffmpeg \
      		-i - \
      		-vcodec copy \
      		-threads 1 \
      		-f v4l2 \
      		"/dev/$(ls -1 /sys/devices/virtual/video4linux)"
    '')

    (writeShellScriptBin "font-menu" ''
      set -euo pipefail
      fc-list --format="%{family[0]}\n" | sort | uniq | fzf | tr -s \n | tr -s [:space:] | wl-copy
    '')
  ];
}
