{ lib, config, ... }:
with lib;
{

  config = mkIf config.features.network.ssh.enable {
    services.openssh = {
      enable = true;
      settings = {
        AllowUsers = [ "s1n7ax" ];
      };
    };
    services.ssh-agent.enable = true;
  };
}
