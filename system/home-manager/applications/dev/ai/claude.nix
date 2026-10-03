{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  claude = config.features.development.ai.claude;
  headroom = config.features.development.ai.headroom;
  skills = import ./skills;
  configDir = config.programs.claude-code.configDir;

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
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    env.CLAUDE_CODE_WALNUT_SPIRE = "1";
    model = "opus";
    effortLevel = "xhigh";
    modelSettings.claude-opus-5-5.effortLevel = "xhigh";
    outputStyle = "Silent";
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
      "context7@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = true;
      "playground@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "mattpocock-skills@claude-plugins-official" = false;
    };
  }
  // lib.optionalAttrs claude.yolo yoloSettings;

  settingsFile = (pkgs.formats.json { }).generate "claude-settings.json" settings;
in
{
  config = lib.mkIf claude.enable {
    programs.claude-code = {
      enable = true;
      package = claudeCode;
      outputStyles.silent = ./claude/silent.md;
    };

    home.file = {
      ".claude/keybindings.json".source = ./claude/keybindings.json;
    }
    # Custom skills, version-controlled here so they're the same on every
    # machine instead of hand-edited under ~/.claude/skills.
    // lib.listToAttrs (
      map (name: {
        name = ".claude/skills/${name}";
        value.source = ./skills/${name};
      }) skills.names
    );

    /**
      Claude Code rewrites settings.json itself (/model, /config, plugin
      toggles), so it cannot be a read-only store symlink, which is what
      programs.claude-code.settings would make. It is copied in on every
      activation instead: this repository is the source of truth and any
      change made from inside Claude is replaced on the next switch.
    */
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run install -Dm0644 ${settingsFile} ${lib.escapeShellArg "${configDir}/settings.json"}
    '';
  };
}
