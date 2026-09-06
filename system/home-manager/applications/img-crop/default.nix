{
  lib,
  runCommand,
  makeWrapper,
  python3,
  gtk4,
  gobject-introspection,
  glib,
  pango,
  gdk-pixbuf,
  graphene,
  harfbuzz,
}:
let
  pythonEnv = python3.withPackages (ps: [
    ps.pygobject3
    ps.pycairo
    ps.pillow
    ps.numpy
  ]);

  typelibDirs = map (p: "${lib.getLib p}/lib/girepository-1.0") [
    gtk4
    gobject-introspection
    glib
    pango
    gdk-pixbuf
    graphene
    harfbuzz
  ];
in
runCommand "img-crop"
  {
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    install -Dm644 ${./main.py} $out/share/img-crop/main.py
    install -Dm644 ${./render.py} $out/share/img-crop/render.py
    install -Dm644 ${./imagefile.py} $out/share/img-crop/imagefile.py
    install -Dm644 ${./perspective.py} $out/share/img-crop/perspective.py
    install -Dm644 ${./selection.py} $out/share/img-crop/selection.py
    install -Dm644 ${./viewport.py} $out/share/img-crop/viewport.py
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/img-crop \
      --add-flags $out/share/img-crop/main.py \
      --prefix GI_TYPELIB_PATH : "${lib.concatStringsSep ":" typelibDirs}"
  ''
