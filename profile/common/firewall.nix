{ ... }:
{
  networking.firewall = {
    enable = true;
    allowPing = false;
  };

  networking.firewall.allowedTCPPorts = [
    8971 # frigate
  ];
}
