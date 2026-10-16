{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.readAloud;
  piper = import ../../shared/piper.nix { inherit pkgs; };
  synth = lib.concatStringsSep " " (piper.synth cfg.rate);
  play = lib.concatStringsSep " " piper.play;
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
        GenericCmdDependency "${piper.bin}"
        AddVoice "en" "MALE1" "lessac"
        DefaultVoice "lessac"
      '';
    };
  };
}
