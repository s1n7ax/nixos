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
        bind-key -n M-a select-window -t 1
        bind-key -n M-r select-window -t 2
        bind-key -n M-s select-window -t 3

        set -g prefix M-t

        bind q kill-server
        bind t new-window
        bind x kill-window

      '';
    };
  };
}
