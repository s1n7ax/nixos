{ ... }:
{
  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  imports = [
    ./options.nix
    ../common/home.nix
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      # Names, not IPs: homelab advertises homelab.local via Avahi, the Mac
      # advertises macbook.local via Bonjour. Static DHCP reservations on the
      # router are still worth doing as backup (then use the IPs here).
      "homelab" = {
        User = "s1n7ax";
        HostName = "homelab.local";
        IdentityFile = "~/.ssh/home_server";
      };

      "64.225.84.64" = {
        User = "root";
        HostName = "64.225.84.64";
        IdentityFile = "~/.ssh/digitalocean";
      };

      # dev microvm (QEMU user-net forward, bound to 127.0.0.1 on desktop).
      # Reachable only from desktop itself.
      "dev" = {
        User = "s1n7ax";
        HostName = "localhost";
        Port = 2222;
        IdentityFile = "~/.ssh/id_ed25519";
      };

      # MacBook. mDNS works until you set the static reservation.
      "macbook" = {
        User = "s1n7ax";
        HostName = "macbook.local";
        IdentityFile = "~/.ssh/home_server";
      };
    };
  };
}
