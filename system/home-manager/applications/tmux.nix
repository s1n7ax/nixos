{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.tools.tmux.enable {
    programs.tmux = {
      enable = true;
      escapeTime = 0;
      terminal = "tmux-256color";
      mouse = false;
      sensibleOnTop = false;
      disableConfirmationPrompt = true;
      historyLimit = 50000;
      baseIndex = 1;
      clock24 = false;
      newSession = true;
      shell = "${pkgs.fish}/bin/fish";
      extraConfig = ''
        unbind-key -a
        bind-key -n M-d detach-client
        bind-key -n M-q kill-server
      '';
    };
  };
}
