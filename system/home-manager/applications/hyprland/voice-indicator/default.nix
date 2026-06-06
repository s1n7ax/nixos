{
  lib,
  runCommand,
  makeWrapper,
  python3,
  gtk4,
  gtk4-layer-shell,
  gobject-introspection,
  glib,
  pango,
  gdk-pixbuf,
  graphene,
  harfbuzz,
  librsvg,
}:
let
  pythonEnv = python3.withPackages (ps: [
    ps.pygobject3
    ps.pycairo
  ]);

  typelibDirs = map (p: "${lib.getLib p}/lib/girepository-1.0") [
    gtk4
    gtk4-layer-shell
    gobject-introspection
    glib
    pango
    gdk-pixbuf
    graphene
    harfbuzz
    librsvg
  ];
in
runCommand "voice-indicator"
  {
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    install -Dm644 ${./main.py} $out/share/voice-indicator/main.py
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/voice-indicator \
      --add-flags $out/share/voice-indicator/main.py \
      --prefix GI_TYPELIB_PATH : "${lib.concatStringsSep ":" typelibDirs}" \
      --prefix LD_PRELOAD : "${lib.getLib gtk4-layer-shell}/lib/libgtk4-layer-shell.so"
  ''
