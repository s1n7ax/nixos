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

        set -s extended-keys on

        set -sg terminal-overrides ",*:RGB"  # true color support
        set -g mouse on
        set -g renumber-windows on  # keep numbering sequential
        set -g repeat-time 1000  # increase "prefix-free" window

        # Theme: borders
        set -g pane-border-lines simple
        set -g pane-border-style fg=black,bright
        set -g pane-active-border-style fg=magenta

        # Theme: status
        set -g status-style bg=default,fg=black,bright
        set -g status-left "   "
        set -g status-right "#[fg=black,bright]%I:%M %p   #S   "

        set -g window-status-format "●"
        set -g window-status-current-format "●"

        set -g window-status-current-style "#{?window_zoomed_flag,fg=yellow,fg=magenta\#,nobold}"
        set -g window-status-bell-style "fg=red,nobold"

        bind-key -n M-d detach-client

        bind-key -n M-a select-window -t 1
        bind-key -n M-r select-window -t 2
        bind-key -n M-s select-window -t 3
        bind-key -n M-t select-window -t 4

        set -g prefix M-t

        set -g automatic-rename on
        set -g automatic-rename-format '#{b:pane_current_path}'

        bind n new-window
        bind x kill-window
      '';
    };
  };
}
