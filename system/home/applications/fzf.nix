{ ... }:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [ "--bind ctrl-n:down,ctrl-e:up" ];
  };
}
