{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "192.168.1.110" = {
        user = "s1n7ax";
        hostname = "192.168.1.110";
        identityFile = "~/.ssh/home_server";
      };

      "64.225.84.64" = {
        user = "root";
        hostname = "64.225.84.64";
        identityFile = "~/.ssh/digitalocean";
      };
    };
  };
}
