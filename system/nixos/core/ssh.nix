{ lib, config, ... }:
with lib;
{

  config = mkIf config.features.network.ssh.enable {
    services.openssh = {
      enable = true;
      settings = {
        AllowUsers = [ "s1n7ax" ];
        # Key-only: only the desktop key in authorizedKeys can log in.
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
