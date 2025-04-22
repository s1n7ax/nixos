{ ... }:
{
  virtualisation.virtualbox.host = {
    enable = true;
    enableKvm = true;
    addNetworkInterface = false;
    enableHardening = true;
  };

  virtualisation.virtualbox.guest = {
    enable = true;
  };
}
