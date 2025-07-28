{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.sh.enable {
    home.packages = with pkgs; [
      shfmt
      fish-lsp
    ];
  };
}
