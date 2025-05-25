{ settings, ... }:
{
  users.users.${settings.username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTyz+PybkD53ewO5SZQCwgFIJlq1MvirnvEFOQ7SIpE srineshnisala@gmail.com"
  ];
}
