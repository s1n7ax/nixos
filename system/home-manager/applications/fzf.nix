{ lib, config, ... }:
lib.mkIf config.features.cli.fzf.enable {
  programs.fzf = {
    enable = true;
    enableZshIntegration = config.settings.shell == "zsh";
    enableFishIntegration = config.settings.shell == "fish";
    defaultOptions = [ "--bind ctrl-n:down,ctrl-e:up" ];
  };
}
