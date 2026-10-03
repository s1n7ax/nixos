{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  common = import ./common.nix { };
  skills = import ./skills;

  # Pi package declarations live in ~/.pi/agent/settings.json. pi-mcp-adapter
  # adds native MCP support to Pi and automatically discovers the shared MCP
  # config from ~/.config/mcp/mcp.json that programs.mcp writes in mcp.nix.
  piSettings = builtins.toJSON {
    packages = [
      {
        source = "npm:pi-mcp-adapter@2.37.0";
      }
    ];
  };

  # Mirrors claude/keybindings.json. A value replaces Pi's default, so the
  # model selector moves from ctrl+l to ctrl+n to free ctrl+l for /new. The
  # half-page keys only apply with tuiMode = "fullscreen". No effort keys:
  # Pi can only cycle thinking level forward (app.thinking.cycle, shift+tab).
  piKeybindings = builtins.toJSON {
    "tui.altScreen.halfPageUp" = "ctrl+u";
    "tui.altScreen.halfPageDown" = "ctrl+d";
    "app.model.select" = "ctrl+n";
    "tui.select.up" = [
      "up"
      "ctrl+e"
    ];
    "tui.select.down" = [
      "down"
      "ctrl+n"
    ];
    "app.session.new" = "ctrl+l";
  };

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

    home.file = {
      ".pi/agent/AGENTS.md".text = common.rules;
      ".pi/agent/settings.json".text = piSettings;
      ".pi/agent/keybindings.json".text = piKeybindings;
    }
    // lib.listToAttrs (
      map (name: {
        name = ".agents/skills/${name}";
        value.source = ./skills/${name};
      }) piSkillNames
    );
  };
}
