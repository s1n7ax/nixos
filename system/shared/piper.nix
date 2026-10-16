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
in
{
  package = pkgs.piper-tts.override {
    withTrain = false;
    withHTTP = false;
    withAlignment = false;
  };

  model = "${voice}/${voiceName}.onnx";

  sampleRate = 22050;
}
