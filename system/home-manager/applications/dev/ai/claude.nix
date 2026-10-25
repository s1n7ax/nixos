{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  ai = config.features.development.ai;
  claude = ai.claude;
  commonRules = builtins.readFile ./AGENTS.md;

  /**
    pi's tool names in ./agents frontmatter, as Claude Code names them. A name
    missing here fails evaluation rather than silently granting nothing.
  */
  claudeToolNames = {
    read = "Read";
    grep = "Grep";
    find = "Glob";
    ls = "Glob";
    bash = "Bash";
    write = "Write";
    edit = "Edit";
  };

  /**
    One of ./agents with its `tools:` line in Claude Code's names, so the
    harness, not the prompt, keeps the reviewer and verifier from editing. An
    agent without a `tools:` line gets every tool in both agents.
  */
  toClaudeAgent =
    file:
    let
      toClaudeLine =
        line:
        if lib.hasPrefix "tools: " line then
          "tools: "
          + lib.concatStringsSep ", " (
            lib.unique (
              map (tool: claudeToolNames.${lib.trim tool}) (lib.splitString "," (lib.removePrefix "tools: " line))
            )
          )
        else
          line;
    in
    lib.concatMapStringsSep "\n" toClaudeLine (lib.splitString "\n" (builtins.readFile file));

  agents =
    lib.mapAttrs'
      (name: _: lib.nameValuePair (lib.removeSuffix ".md" name) (toClaudeAgent (./agents + "/${name}")))
      (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
          builtins.readDir ./agents
        )
      );
  headroom = config.features.development.ai.headroom;
  welcome = import ./welcome {
    inherit pkgs;
    inherit (config.home) username;
  };

  claudeCode =
    if headroom.enable then
      pkgs.symlinkJoin {
        name = "claude-code-headroom";
        paths = [ pkgs-unstable.claude-code ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --set ANTHROPIC_BASE_URL "http://127.0.0.1:${toString headroom.port}"
        '';
      }
    else
      pkgs-unstable.claude-code;

  # Both scripts were written without strict mode (an empty `read` or a
  # missing rate-limit block is normal), so bashOptions stays empty.
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      jq
    ];
    bashOptions = [ ];
    text = builtins.readFile ./claude/statusline.sh;
  };

  gitWorkStatus = pkgs.writeShellApplication {
    name = "claude-git-work-status";
    runtimeInputs = with pkgs; [
      coreutils
      git
      jq
    ];
    bashOptions = [ ];
    text = builtins.readFile ./claude/git-work-status.sh;
  };

  # Yolo skips every permission prompt. Only turn it on for throwaway,
  # sandboxed hosts like the dev microvm; everywhere else Claude asks first.
  yoloSettings = {
    permissions = {
      allow = [
        "Bash"
        "Read"
        "Write"
        "Edit"
        "WebFetch"
        "WebSearch"
      ];
      defaultMode = "bypassPermissions";
    };
    skipDangerousModePermissionPrompt = true;
  };

  settings = {
    env.CLAUDE_CODE_WALNUT_SPIRE = "1";
    model = "opus";
    effortLevel = "xhigh";
    modelSettings.claude-opus-5-5.effortLevel = "xhigh";
    theme = "dark";
    tui = "fullscreen";
    autoCompactEnabled = true;
    enableAllProjectMcpServers = true;
    remoteControlAtStartup = true;
    agentPushNotifEnabled = true;
    skipAutoPermissionPrompt = true;
    statusLine = {
      type = "command";
      command = lib.getExe statusline;
    };
    hooks.Stop = [
      {
        hooks = [
          {
            type = "command";
            command = lib.getExe gitWorkStatus;
            timeout = 15;
            statusMessage = "Checking git state...";
          }
        ];
      }
    ];
    enabledPlugins = {
      "github@claude-plugins-official" = true;
      "skill-creator@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
      "ruby-lsp@claude-plugins-official" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "gopls-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "clangd-lsp@claude-plugins-official" = true;
      "swift-lsp@claude-plugins-official" = true;
      "csharp-lsp@claude-plugins-official" = true;
      "jdtls-lsp@claude-plugins-official" = true;
      "php-lsp@claude-plugins-official" = true;
      "kotlin-lsp@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
      /**
        Only where ./mcp.nix does not already run the server: a second copy
        doubles every tool, and the plugin's playwright lacks the wrapper
        Chromium needs to start.
      */
      "context7@claude-plugins-official" = !(ai.enable && ai.mcp.context7.enable);
      "playwright@claude-plugins-official" = !(ai.enable && ai.mcp.playwright.enable);
      "playground@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "mattpocock-skills@claude-plugins-official" = false;
    };
  }
  // lib.optionalAttrs claude.yolo yoloSettings;
in
{
  config = lib.mkIf claude.enable {
    programs.claude-code = {
      enable = true;
      context = commonRules;
      package = claudeCode;
      plugins = [ welcome.claudePlugin ];
      inherit agents;
      # Read-only store symlink: changes made from inside Claude (/model,
      # /config, plugin toggles) don't persist; edit them here instead.
      inherit settings;
    };

    # Skills: see ./skills (mounted under ~/.claude/skills when ai.enable is
    # also set).
    home.file.".claude/keybindings.json".source = ./claude/keybindings.json;
  };
}
