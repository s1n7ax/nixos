{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  config = mkIf config.features.virtualization.podman.enable {
    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };
    environment.systemPackages = [ pkgs.podman-compose ];
  };
}
