{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  common = import ./common.nix { };
  ai = config.features.development.ai;
in
{
  config = lib.mkIf ai.cursor.enable (
    lib.mkMerge [
      {
        # Cursor CLI agent (cursor.com/cli, binary `cursor-agent`).
        #
        # BYOK: like the other agents here, this repo does not provision a
        # credential for it. Authenticate manually, once per machine, with an
        # interactive login or by exporting CURSOR_API_KEY before invoking it.
        home.packages = [ pkgs-unstable.cursor-cli ];

        # Global rules (same rules system as the editor's .cursor/rules).
        # Project-root AGENTS.md/CLAUDE.md files are picked up automatically
        # on top of this.
        home.file.".cursor/rules/standards.mdc".text = ''
          ---
          description: Shared working-relationship rules for every repo
          alwaysApply: true
          ---
          ${common.rules}
        '';
      }

      # The CLI automatically detects MCP servers from ~/.cursor/mcp.json, so
      # mirror the shared fleet there (same shape programs.mcp writes to
      # ~/.config/mcp/mcp.json in mcp.nix).
      (lib.mkIf (config.programs.mcp.servers != { }) {
        home.file.".cursor/mcp.json".text = builtins.toJSON {
          mcpServers = config.programs.mcp.servers;
        };
      })
    ]
  );
}
