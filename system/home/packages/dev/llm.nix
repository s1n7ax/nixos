{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.llm.enable = lib.mkEnableOption "code assistant environment";

  config = lib.mkIf config.package.dev.llm.enable {
    home.packages = with pkgs; [
      llm-ls
    ];
  };
}
