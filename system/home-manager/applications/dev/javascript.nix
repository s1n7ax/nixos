{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.features.development.javascript.enable {
    home.sessionVariables = {
      PNPM_HOME = "$HOME/.local/share/pnpm";
      PATH = "$HOME/.local/share/pnpm:$PATH";
    };

    # fnm prepends its active Node to PATH and switches on cd into a dir with
    # .node-version/.nvmrc; nixpkgs' nodejs stays the fallback when none is set.
    programs.fish.interactiveShellInit = ''
      fnm env --use-on-cd --shell fish | source
    '';
    programs.zsh.initContent = ''
      eval "$(fnm env --use-on-cd --shell zsh)"
    '';
  };
}
