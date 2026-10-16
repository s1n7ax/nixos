{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.readAloud;
  piper = import ../../../shared/piper.nix { inherit pkgs; };

  pipeline =
    if pkgs.stdenv.isDarwin then
      [
        [
          "/usr/bin/say"
          "-r"
          (toString (builtins.floor (175 * cfg.rate + 0.5)))
          "-f"
          "-"
        ]
      ]
    else
      [
        [
          "${piper.package}/bin/piper"
          "-m"
          piper.model
          "--output-raw"
          "--length-scale"
          (toString (1.0 / cfg.rate))
        ]
        [
          "${pkgs.pipewire}/bin/pw-cat"
          "--playback"
          "--raw"
          "--format"
          "s16"
          "--rate"
          (toString piper.sampleRate)
          "--channels"
          "1"
          "-"
        ]
      ];

  speak = pkgs.writers.writePython3Bin "speak" { flakeIgnore = [ "E501" ]; } (
    builtins.replaceStrings [ "@pipeline@" ] [ (builtins.toJSON pipeline) ] (
      builtins.readFile ./speak.py
    )
  );
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ speak ];
  };
}
