{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  commonRules = builtins.readFile ../AGENTS.md;
  welcome = import ../welcome {
    inherit pkgs;
    inherit (config.home) username;
  };

  # Read by both the packages list below and the assertion in the module body.
  piCursor = config.features.development.ai.pi.cursor;

  /**
    MCP comes from Pi's built-in `mcp` extension, which reads
    ~/.pi/agent/mcp.json; mcp.nix links that to the shared programs.mcp
    config. Don't reinstall pi-mcp-adapter: it also registers `/mcp`, so Pi
    drops the built-in and warns on every launch.
  */
  piSettings = builtins.toJSON {
    defaultModel = "muse-spark-1.3";
    defaultProvider = "meta";

    /**
      Packages declared here load from ~/.pi/agent/npm (`pi install` npm dir)
      on every launch; `pi update --extensions` refreshes them.

      - @juicesharp/rpiv-ask-user-question (npm; github.com/juicesharp/rpiv-mono):
        ask_user_question tool -- structured questionnaire with typed options.
      - pi-memory (npm; github.com/jayzeng/pi-memory):
        memory with qmd-powered semantic search across daily logs, long-term
        memory, and scratchpad.

      features.development.ai.pi.cursor.package appends a pi Cursor provider
      plugin when that option is enabled, which makes Cursor show up in /login
      on hosts that opt in. Entries are additive: nothing is replaced or removed.
    */
    packages = [
      "npm:@juicesharp/rpiv-ask-user-question"
      "npm:pi-memory"
    ]
    ++ lib.optional (piCursor.enable && piCursor.package != "") piCursor.package;
  };

  /**
    Subagent extension shipped with the pi package as an official example
    (examples/extensions/subagent in the pi-monorepo; README there documents
    the security model). Registers a `subagent` tool that spawns an isolated
    `pi` subprocess per task. Sourced from the package so it stays in lockstep
    with the installed pi version. Only index.ts and agents.ts are linked, as
    the example's own install instructions do; its sample agents and workflow
    prompts are skipped -- agents live in ../agents instead, and the workflow
    prompts would shadow the /implement skill of the same name.
  */
  subagentExample = "${pkgs-unstable.pi-coding-agent}/lib/node_modules/pi-monorepo/examples/extensions/subagent";

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
    ctrl+o to alt+o. alt+m is the shared model-select key across Claude,
    Pi and OpenCode (Cursor CLI can't rebind keys at all); Claude's own
    ctrl+n/ctrl+e/ctrl+o input behavior is fixed, since it can't rebind
    cursor-movement keys. Configured key lists replace Pi's defaults, so
    those are repeated.
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
in
{
  config = lib.mkIf config.features.development.ai.pi.enable {
    # cursor.enable without a cursor.package would silently declare no provider,
    # leaving /login without Cursor and no hint why. Fail the build instead.
    assertions = [
      {
        assertion = !piCursor.enable || piCursor.package != "";
        message = "features.development.ai.pi.cursor.enable requires features.development.ai.pi.cursor.package";
      }
    ];

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
      ".pi/agent/AGENTS.md".text = commonRules;
      ".pi/agent/settings.json".text = piSettings;
      ".pi/agent/keybindings.json".text = piKeybindings;
      ".pi/agent/extensions/welcome".source = welcome.piExtension;
      ".pi/agent/extensions/persistent-model.ts".source = ./persistent-model.ts;
      ".pi/agent/extensions/subagent/index.ts".source = "${subagentExample}/index.ts";
      ".pi/agent/extensions/subagent/agents.ts".source = "${subagentExample}/agents.ts";

      # User-level subagent definitions (~/.pi/agent/agents/*.md). The subagent
      # extension discovers these fresh on every invocation.
      ".pi/agent/agents".source = ../agents;
    };
  };
}
