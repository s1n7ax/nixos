{ callPackage }:
callPackage ../../gtk-layer-shell-app.nix { } {
  name = "screen-record-indicator";
  script = ./main.py;
}
