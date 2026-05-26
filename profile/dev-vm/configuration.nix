{ config, lib, ... }:
{
  imports = [
    ../../system/options.nix
    ../common/configuration.nix
    ./options.nix
  ];

  disabledModules = [
    ../../system/nixos/utils/microvm.nix
  ];

  networking.hostName = lib.mkForce "dev-vm";

  users.users.${config.settings.username} = {
    extraGroups = lib.mkForce [
      "wheel"
      "audio"
      "video"
      "users"
      "docker"
    ];
    password = "s1n7ax";
    createHome = true;
    home = "/home/${config.settings.username}";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCbb/a4qlKElECtcA07ImQk+QfOILQ5IkiXjpCRqhlL srineshnisala@gmail.com"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /home/${config.settings.username} 0700 ${config.settings.username} ${config.settings.username} -"
  ];

  services.openssh = {
    settings.PasswordAuthentication = true;
    hostKeys = [
      {
        path = "/persist/ssh-host-keys/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  systemd.services.sshd.unitConfig.RequiresMountsFor = "/persist/ssh-host-keys";
}
