{
  lib,
  config,
  pkgs,
  ...
}:
let
  /**
    Matches the monitor exactly (see `hyprland.nix`), so the screen capture
    fills the canvas edge to edge instead of being letterboxed into a 16:9 box.
  */
  canvas = {
    width = 3440;
    height = 1440;
    fps = 60;
  };

  profileName = "s1n7ax";
  collectionName = "s1n7ax";
  cameraDevice = "/dev/video0";
  recordingPath = "${config.home.homeDirectory}/Videos/Youtube/00 new";
  websocketPort = 4455;

  profile = import ./profile.nix { inherit canvas recordingPath profileName; };
  scenes = import ./scenes.nix {
    inherit
      lib
      canvas
      recordingPath
      collectionName
      cameraDevice
      ;
  };

  basicIni = pkgs.writeText "obs-basic.ini" profile.basicIni;
  recordEncoderJson = pkgs.writeText "obs-record-encoder.json" (
    builtins.toJSON profile.recordEncoder
  );
  scenesJson = pkgs.writeText "obs-scenes.json" (builtins.toJSON scenes);

  obsConfigDir = "${config.xdg.configHome}/obs-studio";
  profileDir = "${obsConfigDir}/basic/profiles/${profileName}";
  scenesFile = "${obsConfigDir}/basic/scenes/${collectionName}.json";
  websocketFile = "${obsConfigDir}/plugin_config/obs-websocket/config.json";

  /**
    OBS dlopen's `libnvidia-encode.so.1` by bare name, so without the NixOS
    driver directory on the loader path NVENC disappears ("Test process
    failed: nvenc_lib") and recording silently falls back to x264 on the same
    CPU the capture is running on.

    `wrapOBS` appends every plugin's `obsWrapperArguments` to the wrapper it
    builds, so an otherwise empty plugin is the cheapest way in — overriding
    obs-studio itself would rebuild it, CEF and all.
  */
  nvencDriverPath = pkgs.runCommandLocal "obs-nvenc-driver-path" {
    passthru.obsWrapperArguments = [
      ''--prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"''
    ];
  } "mkdir -p $out/lib/obs-plugins $out/share/obs/obs-plugins";

  /**
    OBS cannot claim global hotkeys under Wayland, so its own F1-F3 bindings
    only fire while OBS has focus — useless while recording something else.
    This drives the same actions over obs-websocket instead, which is what the
    Hyprland binds call.
  */
  obs-ctl = pkgs.writeShellScriptBin "obs-ctl" ''
    set -euo pipefail

    config=${lib.escapeShellArg websocketFile}

    if [ ! -f "$config" ]; then
      echo "obs-ctl: $config is missing; run home-manager switch first" >&2
      exit 1
    fi

    password=$(${lib.getExe pkgs.jq} -r '.server_password // ""' "$config")

    exec ${lib.getExe pkgs.obs-cmd} \
      --websocket "obsws://localhost:${toString websocketPort}/$password" "$@"
  '';

  jq = lib.getExe pkgs.jq;
in
{
  config = lib.mkIf config.features.productivity.video-production.screen-capture.enable {
    programs.obs-studio = {
      enable = true;
      plugins = [
        pkgs.obs-studio-plugins.obs-source-record
        pkgs.obs-studio-plugins.obs-shaderfilter
        nvencDriverPath
      ];
    };

    home.packages = [
      obs-ctl
      pkgs.obs-cmd
    ];

    /**
      OBS rewrites its whole configuration on exit, so these files cannot be
      store symlinks. They are copied in on every activation instead, which
      means this repository is the source of truth and any tweak made in the
      OBS UI is replaced on the next switch.

      Two runtime-owned values survive that overwrite because they cannot be
      declared: the xdg-desktop-portal restore token (re-prompting for screen
      share on every rebuild would be unusable) and the generated websocket
      password.

      Which profile and collection are active lives in `user.ini` since OBS 31
      split the old `global.ini`; writing it to `global.ini` is silently
      ignored and OBS starts on a fresh "Untitled" collection instead.
    */
    home.activation.obsStudio = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ${pkgs.procps}/bin/pgrep -x obs > /dev/null 2>&1; then
        warnEcho "OBS is running; skipping its configuration update"
      else
        run mkdir -p ${lib.escapeShellArg profileDir} \
          ${lib.escapeShellArg (builtins.dirOf scenesFile)} \
          ${lib.escapeShellArg (builtins.dirOf websocketFile)} \
          ${lib.escapeShellArg recordingPath}

        run install -m 0644 ${basicIni} ${lib.escapeShellArg "${profileDir}/basic.ini"}
        run install -m 0644 ${recordEncoderJson} ${lib.escapeShellArg "${profileDir}/recordEncoder.json"}

        restoreToken=""
        if [ -f ${lib.escapeShellArg scenesFile} ]; then
          restoreToken=$(${jq} -r '
            [ .sources[]? | select(.id == "pipewire-screen-capture-source")
                          | .settings.RestoreToken? // empty ] | first // ""
          ' ${lib.escapeShellArg scenesFile})
        fi

        run ${jq} --arg token "$restoreToken" '
          if $token == "" then .
          else .sources |= map(
            if .id == "pipewire-screen-capture-source"
            then .settings.RestoreToken = $token
            else . end)
          end
        ' ${scenesJson} > ${lib.escapeShellArg "${scenesFile}.new"}
        run mv ${lib.escapeShellArg "${scenesFile}.new"} ${lib.escapeShellArg scenesFile}
        run chmod 0644 ${lib.escapeShellArg scenesFile}

        websocketPassword=""
        if [ -f ${lib.escapeShellArg websocketFile} ]; then
          websocketPassword=$(${jq} -r '.server_password // ""' ${lib.escapeShellArg websocketFile})
        fi
        if [ -z "$websocketPassword" ]; then
          websocketPassword=$(${pkgs.openssl}/bin/openssl rand -base64 24 | tr -d '/+=')
        fi

        run ${jq} -n --arg password "$websocketPassword" '{
          alerts_enabled: false,
          auth_required: true,
          first_load: false,
          server_enabled: true,
          server_password: $password,
          server_port: ${toString websocketPort}
        }' > ${lib.escapeShellArg "${websocketFile}.new"}
        run mv ${lib.escapeShellArg "${websocketFile}.new"} ${lib.escapeShellArg websocketFile}
        run chmod 0600 ${lib.escapeShellArg websocketFile}

        userIni=${lib.escapeShellArg "${obsConfigDir}/user.ini"}
        if [ ! -f "$userIni" ]; then
          printf '[General]\nFirstRun=true\n\n[Basic]\n' > "$userIni"
        elif ! grep -q '^\[Basic\]' "$userIni"; then
          printf '\n[Basic]\n' >> "$userIni"
        fi

        selectActive() {
          if grep -q "^$1=" "$userIni"; then
            ${lib.getExe pkgs.gnused} -i "s|^$1=.*|$1=$2|" "$userIni"
          else
            ${lib.getExe pkgs.gnused} -i "/^\[Basic\]/a $1=$2" "$userIni"
          fi
        }

        selectActive Profile ${profileName}
        selectActive ProfileDir ${profileName}
        selectActive SceneCollection ${collectionName}
        selectActive SceneCollectionFile ${collectionName}.json
      fi
    '';
  };
}
