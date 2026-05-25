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
  };

  systemd.tmpfiles.rules = [
    "d /home/${config.settings.username} 0700 ${config.settings.username} ${config.settings.username} -"
  ];

  services.openssh.settings.PasswordAuthentication = true;
}
