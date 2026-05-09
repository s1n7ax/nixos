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
}
