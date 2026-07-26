{ config, lib, ... }:
# let
# data_path = "${config.home.homeDirectory}/.homelab/adguard";
# in
with lib;
{
  config = mkIf config.features.homelab.adguard.enable {
    # systemd.user.tmpfiles.rules = [
    #   "d %h/.homelab/adguard 0700 - - -"
    #   "d %h/.homelab/adguard/work 0700 - - -"
    #   "d %h/.homelab/adguard/conf 0700 - - -"
    # ];

    virtualisation.quadlet = {
      # services.podman.networks.adguard-network = {
      #   autoStart = true;
      #   driver = "bridge";
      # };
      containers.adguard = {
        containerConfig = {
          image = "adguard/adguardhome:latest";

          volumes = [
            "/opt/adguard/work:/opt/adguardhome/work:Z"
            "/opt/adguard/conf:/opt/adguardhome/conf:Z"
            # "${data_path}/work:/opt/adguardhome/work:Z"
            # "${data_path}/conf:/opt/adguardhome/conf:Z"
          ];

          publishPorts = [
            "53:53/tcp"
            "53:53/udp"
            # "67:67/udp"
            # "68:68/udp"
            # "80:80/tcp"
            # "443:443/tcp"
            # "443:443/udp"
            "3000:80/tcp"
            "853:853/tcp"
            "784:784/udp"
            "853:853/udp"
            "8853:8853/udp"
            "5443:5443/tcp"
            "5443:5443/udp"
          ];
        };
      };
    };
  };
}
