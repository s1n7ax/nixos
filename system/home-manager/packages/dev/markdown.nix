{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.markdown.enable {
    home.packages = with pkgs; [
      cbfmt
      marksman
      markdownlint-cli
      markdownlint-cli2
      python312Packages.mdformat
    ];
  };
}
