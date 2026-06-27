{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = import ./common.nix { };
in
{
  config = lib.mkIf config.features.development.ai.enable {
    # mcp-nixos binary backing the `nixos` MCP server (also used by Claude Code).
    home.packages = [ pkgs.mcp-nixos ];

    programs.mcp = {
      enable = true;
      servers = common.mcpServers;
    };
  };
}
