{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    (python3.withPackages (ps: [
      ps.pygobject3
      ps.numpy
    ]))
    gobject-introspection
    glib
    gtk4
    gtk4-layer-shell
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-plugins-rs
    gst_all_1.gst-libav
    pipewire
    gphoto2
    ffmpeg
    v4l-utils
    pulseaudio
    procps
    grim
    jq
  ];

  shellHook =
    let
      typelibs = pkgs.lib.makeSearchPath "lib/girepository-1.0" (
        with pkgs;
        [
          glib.out
          gtk4
          gtk4-layer-shell
          gdk-pixbuf
          pango.out
          harfbuzz
          graphene
          cairo
          gst_all_1.gstreamer.out
          gst_all_1.gst-plugins-base
        ]
      );
      plugins = pkgs.lib.makeSearchPath "lib/gstreamer-1.0" [
        pkgs.gst_all_1.gstreamer.out
        pkgs.gst_all_1.gst-plugins-base
        pkgs.gst_all_1.gst-plugins-good
        pkgs.gst_all_1.gst-plugins-bad
        pkgs.gst_all_1.gst-plugins-ugly
        pkgs.gst_all_1.gst-plugins-rs
        pkgs.gst_all_1.gst-libav
        pkgs.pipewire
      ];
    in
    ''
      export GI_TYPELIB_PATH="${typelibs}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
      export GST_PLUGIN_SYSTEM_PATH_1_0="${plugins}"
      export GDK_BACKEND=wayland
      # gtk4-layer-shell hooks wl_display_connect, so it has to be loaded
      # BEFORE libwayland-client. PyGObject dlopens the typelib long after
      # python already pulled libwayland in, so the hook never lands and every
      # layer-shell call warns "GtkWindow is not a layer surface". The
      # preload is the documented escape hatch for exactly this case.
      export LD_PRELOAD="${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so''${LD_PRELOAD:+:$LD_PRELOAD}"
    '';
}
