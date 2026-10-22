{
  pkgs,
  voice ? "en_US-lessac-medium",
  speaker ? null,
  pulseServer ? null,
}:
let
  /**
    Piper voices that can be selected, keyed by `<locale>-<name>-<quality>`.
  */
  voices = {
    "en_US-lessac-medium" = {
      onnx = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
      json = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
    };
    "en_US-amy-medium" = {
      onnx = "sha256-s6bke1e4x/vmoM4lGBYaUPWanN2KUINcAssCvdYgbBg=";
      json = "sha256-laI+tNQpCdON9zu5rH9F9Zfb/N4tG/lSb96vVGaXfXc=";
    };
  };

  hashes = voices.${voice} or (throw "piper: unknown voice ${voice}");
  parts = pkgs.lib.splitString "-" voice;
  locale = builtins.elemAt parts 0;
  language = builtins.head (pkgs.lib.splitString "_" locale);
  voiceUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/${language}/${locale}/${builtins.elemAt parts 1}/${builtins.elemAt parts 2}";

  model = pkgs.linkFarm "piper-voice-${voice}" {
    "${voice}.onnx" = pkgs.fetchurl {
      url = "${voiceUrl}/${voice}.onnx";
      hash = hashes.onnx;
    };
    "${voice}.onnx.json" = pkgs.fetchurl {
      url = "${voiceUrl}/${voice}.onnx.json";
      hash = hashes.json;
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
    Voice name without the locale and quality, e.g. `lessac`.
  */
  name = builtins.elemAt parts 1;

  /**
    Argv that turns text on stdin into raw audio on stdout, `rate` times
    faster than the voice's natural speed.
  */
  synth =
    rate:
    [
      bin
      "-m"
      "${model}/${voice}.onnx"
      "--output-raw"
      "--length-scale"
      (toString (1.0 / rate))
    ]
    ++ pkgs.lib.optionals (speaker != null) [
      "--speaker"
      (toString speaker)
    ];

  /**
    Argv that plays the raw audio `synth` writes.

    With `pulseServer` set the audio is sent to that PulseAudio server (a
    remote host) over the network; otherwise it goes to the local PipeWire
    daemon.
  */
  play =
    if pulseServer == null then
      [
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
      ]
    else
      [
        "${pkgs.pulseaudio}/bin/pacat"
        "--playback"
        "--server"
        pulseServer
        "--raw"
        "--format"
        "s16le"
        "--rate"
        "22050"
        "--channels"
        "1"
      ];
}
