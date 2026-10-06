{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  claude = config.features.development.ai.claude;
  commonRules = builtins.readFile ./AGENTS.md;
  headroom = config.features.development.ai.headroom;

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
      "context7@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = true;
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
      # Read-only store symlink: changes made from inside Claude (/model,
      # /config, plugin toggles) don't persist; edit them here instead.
      inherit settings;
    };

    # Skills: see ./skills (mounted under ~/.claude/skills when ai.enable).
    home.file.".claude/keybindings.json".source = ./claude/keybindings.json;
  };
}
