{
  lib,
  config,
  pkgs,
  # pkgs-devenv,
  # pkgs-my,
  ...
}:
{
  options.package.dev.container.enable = lib.mkEnableOption "container environment";

  config = lib.mkIf config.package.dev.container.enable {
    home.packages = with pkgs; [
      # pkgs-devenv.devenv
      # pkgs-my.devcontainer
      lazydocker
      dockerfile-language-server-nodejs
      hadolint
    ];
  };
}
