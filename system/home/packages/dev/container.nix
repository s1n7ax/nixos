{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.container.enable = lib.mkEnableOption "container environment";

  config = lib.mkIf config.package.dev.container.enable {
    home.packages = with pkgs; [
      #devcontainer
      lazydocker
      dockerfile-language-server-nodejs
      hadolint
    ];
  };
}
