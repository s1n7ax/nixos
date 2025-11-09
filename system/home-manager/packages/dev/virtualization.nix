{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.virtualization.enable {
    home.packages = with pkgs; [
      docker-compose-language-service
      dockerfile-language-server
    ];
  };
}
