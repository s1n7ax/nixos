{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./options.nix
  ];

  environment.sessionVariables = lib.mkIf config.features.security.gpg.enable {
    GPG_TTY = "$(tty)";
  };

  fileSystems."/storage" = {
    device = "/dev/disk/by-uuid/a207886d-bcc6-4e13-a164-19550e340889";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/storage-hdd" = {
    device = "/dev/disk/by-uuid/58670f4d-422d-4fbc-b179-78c0cb8d0e5b";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=1min"
      "x-systemd.idle-timeout=0"
    ];
  };

  users.users.${config.settings.username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTyz+PybkD53ewO5SZQCwgFIJlq1MvirnvEFOQ7SIpE srineshnisala@gmail.com"
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };
}
