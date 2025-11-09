{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.container.enable {
    home.packages = with pkgs; [
      devcontainer
      lazydocker
      dockerfile-language-server
      hadolint
    ];
  };
}
