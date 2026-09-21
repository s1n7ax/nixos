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
/**
  Packages a single-file GTK4 layer-shell app written in Python.

  `name` becomes the executable and the `share/` subdirectory, `script` is the
  `main.py` it runs, and `pythonPackages` selects libraries needed on top of
  pygobject3. The wrapper pins GI_TYPELIB_PATH because the GObject bindings are
  resolved at runtime, and LD_PRELOADs libgtk4-layer-shell because the library
  has to hook GDK before the first Wayland surface is created.
*/
{
  name,
  script,
  pythonPackages ? (_: [ ]),
}:
let
  pythonEnv = python3.withPackages (ps: [ ps.pygobject3 ] ++ pythonPackages ps);

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
runCommand name
  {
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    install -Dm644 ${script} $out/share/${name}/main.py
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/${name} \
      --add-flags $out/share/${name}/main.py \
      --prefix GI_TYPELIB_PATH : "${lib.concatStringsSep ":" typelibDirs}" \
      --prefix LD_PRELOAD : "${lib.getLib gtk4-layer-shell}/lib/libgtk4-layer-shell.so"
  ''
