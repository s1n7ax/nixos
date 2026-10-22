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

    # fnm owns Node on PATH when enabled (macOS); auto-switch from .nvmrc /
    # .node-version. Hosts where Nix/direnv already provides Node leave it off.
    programs.fish.interactiveShellInit =
      lib.mkIf (config.features.development.javascript.fnm.enable && config.features.shell.fish.enable)
        (
          lib.mkAfter ''
            fnm env --use-on-cd --shell fish | source
          ''
        );

    programs.zsh.initContent =
      lib.mkIf (config.features.development.javascript.fnm.enable && config.features.shell.zsh.enable)
        (
          lib.mkAfter ''
            eval "$(fnm env --use-on-cd --shell zsh)"
          ''
        );
  };
}
