{ config, lib, ... }:
with lib;
{
  config.virtualisation.podman = mkIf config.features.development.podman.enable {
    enable = true;
  };
}
