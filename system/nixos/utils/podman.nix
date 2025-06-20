{
  config,
  lib,
  pkgs-stable,
  ...
}:
with lib;
{
  config.virtualisation.podman = mkIf config.features.development.podman.enable {
    enable = true;
    package = pkgs-stable.podman;
  };
}
