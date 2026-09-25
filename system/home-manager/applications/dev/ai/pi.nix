{
  pkgs-unstable,
  config,
  lib,
  ...
}:
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
    home.packages = [ pkgs-unstable.pi-coding-agent ];
  };
}
