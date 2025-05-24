{ config, lib, ... }:
with lib;
{
  config = mkIf config.features.security.gpg.enable {
    environment.sessionVariables = {
      GPG_TTY = "$(tty)";
    };
  };
}
