{ ... }:
{
  programs.fish = {
    enable = true;
    shellInit = ''
      # disable greeting
      set -g fish_greeting
    '';
  };
}
