{
  config,
  lib,
  ...
}:
let
  common = import ./common.nix;
in
{
  config = lib.mkIf config.features.development.ai.enable {
    programs.mcp = {
      enable = true;
      servers = common.mcpServers;
    };
  };
}
