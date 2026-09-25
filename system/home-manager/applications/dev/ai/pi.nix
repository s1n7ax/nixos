{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  skills = import ./skills;

  # Pi loads skills from ~/.agents/skills, following the same Agent Skills
  # spec as Claude Code's SKILL.md -- so the same directories are portable.
  # "wayfinder" is skipped here: an unrelated third-party skill of the same
  # name is already installed there by hand, and this must not clobber it.
  piSkillNames = lib.filter (name: name != "wayfinder") skills.names;
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
    home.packages = [ pkgs-unstable.pi-coding-agent ];

    home.file = lib.listToAttrs (
      map (name: {
        name = ".agents/skills/${name}";
        value.source = ./skills/${name};
      }) piSkillNames
    );
  };
}
