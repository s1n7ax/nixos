{ lib, config, ... }:
{
  options.package.podman.enable = lib.mkEnableOption "Podman";

  config.virtualisation.podman = {
    enable = config.package.podman.enable;
  };
}
