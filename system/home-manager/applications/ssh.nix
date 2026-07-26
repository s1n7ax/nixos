{ lib, config, ... }:
with lib;
mkIf config.features.network.ssh.agent.enable {
  services.ssh-agent.enable = true;
}
