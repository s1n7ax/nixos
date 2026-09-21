{ callPackage }:
callPackage ../../gtk-layer-shell-app.nix { } {
  name = "voice-indicator";
  script = ./main.py;
  pythonPackages = ps: [ ps.pycairo ];
}
