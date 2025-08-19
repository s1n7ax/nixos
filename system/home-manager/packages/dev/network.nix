{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.network.monitoring.enable {
    home.packages = with pkgs; [
      vnstat
      speedtest-cli
    ];
  };
}