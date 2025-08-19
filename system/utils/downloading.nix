{ config, pkgs, lib, ... }:

with lib;

{
  config = mkIf config.features.tools.downloading.enable {
    environment.systemPackages = with pkgs; [
      wget
      curl
      aria2
    ];
  };
}