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
    ./meter.py
    ./pipeline.py
    ./session.py
    ./supervisor.py
    ./takes.py
  ];

  diameter = "540";
  feather = "3";
  centre = "269.5";
  radius = "270";
in
runCommand "record"
  {
    nativeBuildInputs = [
      makeWrapper
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

    ffmpeg -v error -f lavfi \
      -i "color=c=black:s=${diameter}x${diameter},format=gray,geq=lum='clip((${radius}-hypot(X-${centre},Y-${centre}))*255/${feather},0,255)'" \
      -frames:v 1 $out/share/record/circle-mask-${diameter}.png

    makeWrapper ${python3}/bin/python3 $out/bin/record \
      --add-flags $out/share/record/main.py \
      --prefix PATH : "${lib.makeBinPath runtimeInputs}"
  ''
