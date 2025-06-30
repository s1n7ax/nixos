{ config, lib, ... }:
with lib;
{
  config = mkIf config.features.homelab.entertainment.enable {
    services.podman.networks.entertainment-network = {
      autoStart = true;
      driver = "bridge";
    };
  };

  imports = [
    ./jellyfin.nix
    ./prowlarr.nix
    ./sonarr.nix
    ./radarr.nix
    ./qbittorrent.nix
  ];
}