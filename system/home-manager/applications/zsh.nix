{ config, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    oh-my-zsh.enable = true;
    programs.zsh.dotDir = "${config.xdg.configHome}/zsh";
    localVariables = {
      PATH = "/home/s1n7ax/.cargo/bin:$PATH";
    };

    syntaxHighlighting.enable = true;
    initContent = ''
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
