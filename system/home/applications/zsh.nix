{ ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    oh-my-zsh.enable = true;
    sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1"; # no cursor fix for wayland
      EDITOR = "nvim";
      TERM = "alacritty";
    };
    localVariables = {
      PATH = "/home/s1n7ax/.cargo/bin:$PATH";
    };

    syntaxHighlighting.enable = true;
    initExtra = ''
      # this disables the <c-s> terminal freeze
      stty -ixon

      bindkey "^n" vi-backward-word
      bindkey "^e" vi-forward-word
      bindkey "^w" vi-backward-kill-word
      bindkey "^a" beginning-of-line
      bindkey "^o" end-of-line
      bindkey "^l" clear-screen
      bindkey "^s" up-line-or-history
      bindkey "^t" down-line-or-history
    '';
  };
}
