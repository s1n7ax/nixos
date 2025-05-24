{ lib, config, ... }:
with lib;
{
  services.ssh-agent.enable = true;
}
