{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.markdown.enable = lib.mkEnableOption "markdown environment";

  config = lib.mkIf config.package.dev.markdown.enable {
    home.packages = with pkgs; [
      cbfmt
      marksman
      markdownlint-cli
      markdownlint-cli2
      python311Packages.mdformat
    ];
  };
}
