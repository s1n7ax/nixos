{ ... }: {
  programs.mpv = {
    enable = true;
    bindings = {
      i = "seek  5";
      m = "seek -5";
      e = "add volume 2";
      n = "add volume -2";
      "Ctrl++" = "add video-zoom 0.1";
      "Ctrl+-" = "add video-zoom -0.1";
    };
  };
}
