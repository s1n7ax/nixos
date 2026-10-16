{ pkgs }:
let
  voiceName = "en_US-lessac-medium";
  voiceUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium";

  voice = pkgs.linkFarm "piper-voice-${voiceName}" {
    "${voiceName}.onnx" = pkgs.fetchurl {
      url = "${voiceUrl}/${voiceName}.onnx";
      hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
    };
    "${voiceName}.onnx.json" = pkgs.fetchurl {
      url = "${voiceUrl}/${voiceName}.onnx.json";
      hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
    };
  };

  package = pkgs.piper-tts.override {
    withTrain = false;
    withHTTP = false;
    withAlignment = false;
  };
in
rec {
  bin = "${package}/bin/piper";

  /**
    Argv that turns text on stdin into raw audio on stdout, `rate` times
    faster than the voice's natural speed.
  */
  synth = rate: [
    bin
    "-m"
    "${voice}/${voiceName}.onnx"
    "--output-raw"
    "--length-scale"
    (toString (1.0 / rate))
  ];

  /**
    Argv that plays the raw audio `synth` writes.
  */
  play = [
    "${pkgs.pipewire}/bin/pw-cat"
    "--playback"
    "--raw"
    "--format"
    "s16"
    "--rate"
    "22050"
    "--channels"
    "1"
    "-"
  ];
}
