{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.readAloud;
  piper = import ../../shared/piper.nix { inherit pkgs; };
  piperBin = "${piper.package}/bin/piper";
  synth = "${piperBin} -m ${piper.model} --output-raw --length-scale ${toString (1.0 / cfg.rate)}";
  play = "${pkgs.pipewire}/bin/pw-cat --playback --raw --format s16 --rate ${toString piper.sampleRate} --channels 1 -";
in
{
  config = lib.mkIf cfg.enable {
    services.speechd = {
      enable = true;
      config = ''
        LogLevel 3
        LogDir "default"
        DefaultVolume 100
        SymbolsPreproc "char"
        SymbolsPreprocFile "gender-neutral.dic"
        SymbolsPreprocFile "font-variants.dic"
        SymbolsPreprocFile "symbols.dic"
        SymbolsPreprocFile "emojis.dic"
        SymbolsPreprocFile "orca.dic"
        SymbolsPreprocFile "orca-chars.dic"
        Include "clients/*.conf"
        AddModule "piper" "sd_generic" "piper.conf"
        DefaultModule piper
        DefaultLanguage "en"
      '';
      modules.piper = ''
        GenericExecuteSynth "printf %s \'$DATA\' | ${synth} | ${play}"
        GenericCmdDependency "${piperBin}"
        AddVoice "en" "MALE1" "lessac"
        DefaultVoice "lessac"
      '';
    };
  };
}
