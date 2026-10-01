{ config, lib, ... }:
let
  backend = config.settings.network.backend;
in
{
  networking.networkmanager = lib.mkIf (backend == "networkmanager") {
    enable = true;
    wifi.backend = "iwd";
  };

  networking.wireless.iwd = lib.mkIf (backend == "iwd") {
    enable = true;
  };

  networking.enableIPv6 = false;

  # Advertises <hostname>.local and resolves peers' .local names.
  # No firewall rules needed: networking.firewall is disabled (see firewall.nix).
  services.avahi = lib.mkIf config.features.network.mdns.enable {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };
}
