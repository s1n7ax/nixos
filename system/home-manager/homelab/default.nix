{ config, lib, ... }:
with lib;
{
  config = mkIf config.features.virtualization.podman.enable {
    services.podman.enable = true;
    services.podman.enableTypeChecks = true;
    services.podman.autoUpdate.enable = true;
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab 0700 - - -"
    ];
  };

  imports = [
    ./mqtt.nix
    ./z2m.nix
    ./home-assistant.nix
    ./frigate.nix
    ./homepage.nix
    ./pairdrop.nix
    ./entertainment
  ];
}
