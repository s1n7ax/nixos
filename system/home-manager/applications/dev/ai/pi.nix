{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  commonRules = builtins.readFile ./AGENTS.md;
  skills = import ./skills;
  welcome = import ./welcome {
    inherit pkgs;
    inherit (config.home) username;
  };

  /**
    MCP comes from Pi's built-in `mcp` extension, which reads
    ~/.pi/agent/mcp.json; mcp.nix links that to the shared programs.mcp
    config. Don't reinstall pi-mcp-adapter: it also registers `/mcp`, so Pi
    drops the built-in and warns on every launch.
  */
  piSettings = builtins.toJSON {
    defaultModel = "muse-spark-1.3";
    defaultProvider = "meta";
  };

  /**
    Pi's ~/.pi/agent/keybindings.json is a flat `{ "<action id>": key | [keys] }`
    map, not Claude Code's `{ bindings = [ { context; bindings; } ]; }` schema,
    so claude/keybindings.json can't be shared: Pi silently drops every entry.
    These mirror the Claude bindings with Pi's action ids
    (docs/keybindings.md in the pi-coding-agent package).

    - ctrl+u / ctrl+d scroll the fullscreen transcript. Pi checks them before
      the editor, so they replace delete-to-line-start, delete-char-forward
      and ctrl+d exit there (ctrl+c twice still exits).
    - A configured key list replaces Pi's defaults, so up and down are
      listed again to keep them.
    - ctrl+l starts a new session (Pi's /new), matching Claude's
      `command:clear`. It is not `app.clear`, which exits on a second press.
    - The session picker checks its named filter before list movement, so
      it moves off ctrl+n for ctrl+n to move down there.
    - Claude's ctrl+m / ctrl+i effort keys have no Pi equivalent: Pi only
      cycles thinking (shift+tab), and ctrl+i is tab in most terminals.

    Editor cursor movement mirrors fish.nix: ctrl+n/ctrl+e move by word and
    ctrl+o jumps to line end (ctrl+a line start and ctrl+w kill-word are
    already Pi editor defaults). App-level actions are checked before the
    editor, so model select moves off ctrl+n to alt+m and tool expand off
    ctrl+o to alt+o -- diverging from Claude's ctrl+n modelPicker, which
    stays: Claude Code can't rebind cursor-movement keys at all.
    Configured key lists replace Pi's defaults, so those are repeated.
  */
  piKeybindings = builtins.toJSON {
    "tui.altScreen.halfPageUp" = "ctrl+u";
    "tui.altScreen.halfPageDown" = "ctrl+d";
    "app.model.select" = "alt+m";
    "app.tools.expand" = "alt+o";
    "app.session.new" = "ctrl+l";
    "tui.select.up" = [
      "up"
      "ctrl+e"
    ];
    "tui.select.down" = [
      "down"
      "ctrl+n"
    ];
    "app.session.toggleNamedFilter" = "alt+n";
    "tui.editor.cursorWordLeft" = [
      "alt+left"
      "ctrl+left"
      "alt+b"
      "ctrl+n"
    ];
    "tui.editor.cursorWordRight" = [
      "alt+right"
      "ctrl+right"
      "alt+f"
      "ctrl+e"
    ];
    "tui.editor.cursorLineEnd" = [
      "end"
      "ctrl+o"
    ];
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
      ".pi/agent/AGENTS.md".text = commonRules;
      ".pi/agent/settings.json".text = piSettings;
      ".pi/agent/keybindings.json".text = piKeybindings;
      ".pi/agent/extensions/welcome".source = welcome.piExtension;
    }
    // lib.listToAttrs (
      map (name: {
        name = ".agents/skills/${name}";
        value.source = ./skills/${name};
      }) piSkillNames
    );
  };
}
