{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.sh.enable {
    home.packages = with pkgs; [
      bash-language-server
      shellcheck
      shfmt
      fish-lsp
    ];
  };
}
