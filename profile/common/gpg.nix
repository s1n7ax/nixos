{ config, lib, ... }:
with lib;
{
  config = mkMerge [
    # GPG TTY environment variable (needed for GPG signing)
    (mkIf config.features.security.gpg.enable {
      environment.sessionVariables = {
        GPG_TTY = "$(tty)";
      };
    })
    
    # GPG agent settings
    {
      programs.gnupg.agent.settings = {
        # expires after 15 min
        default-cache-ttl = 900000;
      };
    }
  ];
}
