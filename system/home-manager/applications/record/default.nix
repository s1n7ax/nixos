{
  lib,
  runCommand,
  makeWrapper,
  python3,
  ffmpeg_6-full,
  wf-recorder,
  gphoto2,
  pipewire,
}:
let
  runtimeInputs = [
    ffmpeg_6-full
    wf-recorder
    gphoto2
    pipewire
  ];

  modules = [
    ./main.py
    ./audio.py
    ./camera.py
    ./config.py
    ./errors.py
    ./mask.py
    ./meter.py
    ./pipeline.py
    ./session.py
    ./supervisor.py
    ./takes.py
  ];
in
runCommand "record"
  {
    nativeBuildInputs = [
      makeWrapper
      python3
      ffmpeg_6-full
    ];
    meta = {
      description = "One-command screen + Canon R5 recording, composited and encoded in a single ffmpeg";
      mainProgram = "record";
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p $out/share/record
    ${lib.concatMapStringsSep "\n" (
      module: "install -Dm644 ${module} $out/share/record/${baseNameOf (toString module)}"
    ) modules}

    # the circle's geometry lives only in config.py; mask.py hands it to ffmpeg here
    cd $out/share/record
    ffmpeg -v error -f lavfi -i "$(python3 mask.py lavfi)" -frames:v 1 "$(python3 mask.py filename)"

    makeWrapper ${python3}/bin/python3 $out/bin/record \
      --add-flags $out/share/record/main.py \
      --prefix PATH : "${lib.makeBinPath runtimeInputs}"
  ''
