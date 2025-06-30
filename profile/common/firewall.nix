{ ... }:
{
  networking.firewall = {
    enable = false;
    allowPing = false;
  };

  networking.firewall.allowedTCPPorts = [
    8971 # frigate
  ];
}
