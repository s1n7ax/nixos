{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  common = import ./common.nix { };

  # Pi package declarations live in ~/.pi/agent/settings.json. pi-mcp-adapter
  # adds native MCP support to Pi and automatically discovers the shared MCP
  # config from ~/.config/mcp/mcp.json that programs.mcp writes in mcp.nix.
  piSettings = builtins.toJSON {
    defaultModel = "muse-spark-1.3";
    defaultProvider = "meta";
    packages = [
      {
        source = "npm:pi-mcp-adapter@2.37.0";
      }
    ];
  };
in
{
  config = lib.mkIf config.features.development.ai.pi.enable {
    # pi-coding-agent (github.com/badlogic/pi-mono, pi.dev) -- Claude-Code-style
    # CLI coding agent, packaged in nixpkgs unstable. Not to be confused with
    # Inflection AI's "Pi" chatbot.
    #
    # BYOK: like Claude Code above, this repo does not provision a credential
    # for it -- sops-nix here only manages homelab service secrets, not
    # personal LLM API keys. Authenticate manually, once per machine, with
    # either:
    #   - `pi auth login` (stores a key/OAuth token in ~/.pi/agent/auth.json)
    #   - or export ANTHROPIC_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY (etc.)
    #     in the shell before invoking `pi`.
    #
    # Skills live under ~/.agents/skills (mounted by ./skills when ai.enable).
    home.packages = [ pkgs-unstable.pi-coding-agent ];

    home.file = {
      ".pi/agent/AGENTS.md".text = common.rules;
      ".pi/agent/settings.json".text = piSettings;
    };
  };
}
