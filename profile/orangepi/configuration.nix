{ config, lib, ... }:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./options.nix
  ];

  networking.hostName = lib.mkForce "orangepi";

  users.users.${config.settings.username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTyz+PybkD53ewO5SZQCwgFIJlq1MvirnvEFOQ7SIpE srineshnisala@gmail.com"
  ];

  # Mali-G610 through the mainline panthor driver.
  hardware.graphics.enable = true;
}
