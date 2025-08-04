{ ... }:
{
  programs.fish = {
    enable = true;
    shellInit = ''
      stty -ixon

      set -x PATH $PATH ~/.cargo/bin 

      # disable greeting
      set -g fish_greeting


      bind ctrl-n backward-word and backward-word and forward-word
      bind ctrl-e forward-word
      bind ctrl-w backward-kill-word
      bind ctrl-a beginning-of-line
      bind ctrl-o end-of-line
    '';
  };
}
