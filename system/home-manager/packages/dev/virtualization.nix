{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.virtualization.enable {
    home.packages = with pkgs; [
      devcontainer
      lazydocker
      dockerfile-language-server
      docker-compose-language-service
      hadolint
    ];
  };
}
