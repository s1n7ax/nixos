{ config, ... }:
{
  config.virtualisation.podman = {
    enable = config.features.development.podman.enable;
  };
}
