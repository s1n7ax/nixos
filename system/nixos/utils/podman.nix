{
  config,
  lib,
  pkgs-stable,
  ...
}:
with lib;
{
  config.virtualisation.podman = mkIf config.features.virtualization.podman.enable {
    enable = true;
    package = pkgs-stable.podman;
    autoPrune.enable = true;
  };
}
