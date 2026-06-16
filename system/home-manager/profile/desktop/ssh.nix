{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "192.168.1.110" = {
        User = "s1n7ax";
        HostName = "192.168.1.110";
        IdentityFile = "~/.ssh/home_server";
      };

      "64.225.84.64" = {
        User = "root";
        HostName = "64.225.84.64";
        IdentityFile = "~/.ssh/digitalocean";
      };

      "dev" = {
        User = "s1n7ax";
        HostName = "localhost";
        Port = 2222;
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
