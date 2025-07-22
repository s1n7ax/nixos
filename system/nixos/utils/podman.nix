{
  config,
  lib,
  ...
}:
with lib;
{
  config.virtualisation.podman = mkIf config.features.virtualization.podman.enable {
    enable = true;
    autoPrune.enable = true;
  };
}
