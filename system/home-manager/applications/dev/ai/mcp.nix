{
  config,
  lib,
  pkgs,
  ...
}:
let
  ai = config.features.development.ai;
  cfg = ai.mcp;

  # ha-mcp only takes credentials from the environment. Read the token from
  # sops at launch so it never lands in the store or a generated MCP config.
  homeAssistantMcp = pkgs.writeShellScript "home-assistant-mcp" ''
    set -eu
    export HOMEASSISTANT_URL=${lib.escapeShellArg cfg.home-assistant.url}
    HOMEASSISTANT_TOKEN="$(< ${lib.escapeShellArg config.sops.secrets."home-assistant/mcp_token".path})"
    export HOMEASSISTANT_TOKEN
    exec ${lib.getExe pkgs.ha-mcp} "$@"
  '';

  /**
    Slack's MCP has no dynamic client registration, so each client needs a
    pre-registered Slack app. The IDs below are the public ones Slack's docs
    give for Claude Code and Cursor (docs.slack.dev/ai/slack-mcp-server);
    Claude Code's app is registered for http://localhost:3118/callback, and
    Pi reuses it by sending that exact redirect URI.
  */
  slackUrl = "https://mcp.slack.com/mcp";
  slackClaudeClientId = "1601185624273.8899143856786";
  slackCursorClientId = "3660753192626.8903469228982";

  /**
    Per-client copy of the shared mcp.json, shaped the way programs.mcp shapes
    it, with client-specific attrs merged into individual servers.
  */
  mkMcpJson =
    name: overrides:
    (pkgs.formats.json { }).generate name {
      mcpServers = lib.mapAttrs (
        _: server:
        lib.hm.mcp.transformMcpServer {
          inherit server;
          extraTransforms = [ lib.hm.mcp.addType ];
          exclude = [ "serverUrl" ];
        }
      ) (lib.recursiveUpdate config.programs.mcp.servers overrides);
    };

  # Single MCP fleet, with each server enabled or disabled per-host through the
  # profile's features.development.ai.mcp.* options.
  servers =
    lib.optionalAttrs cfg.nixos.enable {
      nixos.command = lib.getExe pkgs.mcp-nixos;
    }
    // lib.optionalAttrs cfg.playwright.enable {
      playwright = {
        command = lib.getExe pkgs.playwright-mcp;
        args = lib.optional cfg.playwright.headless "--headless";
      };
    }
    // lib.optionalAttrs cfg.context7.enable {
      context7.command = lib.getExe pkgs.context7-mcp;
    }
    // lib.optionalAttrs cfg.svelte.enable {
      svelte = {
        command = "npx";
        args = [
          "-y"
          "@sveltejs/mcp"
        ];
      };
    }
    // lib.optionalAttrs cfg.nextjs.enable {
      nextjs = {
        command = "npx";
        args = [
          "-y"
          "next-devtools-mcp@latest"
        ];
      };
    }
    // lib.optionalAttrs cfg.tailwindcss.enable {
      tailwindcss = {
        command = "npx";
        args = [
          "-y"
          "tailwindcss-mcp-server"
        ];
      };
    }
    // lib.optionalAttrs cfg.chakra-ui.enable {
      chakra-ui = {
        command = "npx";
        args = [
          "-y"
          "@chakra-ui/react-mcp"
        ];
      };
    }
    // lib.optionalAttrs cfg.jira.enable {
      jira.url = "https://mcp.atlassian.com/v2/mcp";
    }
    // lib.optionalAttrs cfg.home-assistant.enable {
      home-assistant.command = "${homeAssistantMcp}";
    }
    // lib.optionalAttrs cfg.slack.enable {
      slack.url = slackUrl;
    };
in
{
  config = lib.mkIf ai.enable (
    lib.mkMerge [
      {
        programs.mcp = {
          enable = true;
          servers = servers;
        };
      }

      # Claude Code ignores ~/.config/mcp/mcp.json; home-manager wraps `claude`
      # with a generated --plugin-dir carrying the same server list instead. Pi
      # gets the shared instructions via ~/.pi/agent/AGENTS.md in pi.nix.
      (lib.mkIf ai.claude.enable {
        programs.claude-code.mcpServers = lib.recursiveUpdate servers (
          lib.optionalAttrs cfg.slack.enable {
            slack.oauth = {
              clientId = slackClaudeClientId;
              callbackPort = 3118;
            };
          }
        );
      })

      /**
        Pi's built-in MCP support reads only ~/.pi/agent/mcp.json, so link it
        to a copy of the shared file. The link is read-only: toggling a server
        globally in Pi's `/mcp` fails; "Disable in this project" writes
        .pi/mcp.json.
      */
      (lib.mkIf ai.pi.enable {
        home.file.".pi/agent/mcp.json".source = mkMcpJson "pi-mcp.json" (
          lib.optionalAttrs cfg.slack.enable {
            slack.oauth = {
              clientId = slackClaudeClientId;
              callbackUrl = "http://localhost:3118/callback";
            };
          }
        );
      })

      /**
        The Cursor CLI reads ~/.cursor/mcp.json. Its static-OAuth key is
        `auth.CLIENT_ID`, which would switch Pi's OAuth off, so Cursor gets
        its own copy.
      */
      (lib.mkIf ai.cursor.enable {
        home.file.".cursor/mcp.json".source = mkMcpJson "cursor-mcp.json" (
          lib.optionalAttrs cfg.slack.enable {
            slack.auth.CLIENT_ID = slackCursorClientId;
          }
        );
      })

      /**
        home-manager's OpenCode transform drops unknown attrs and merges
        settings.mcp shallowly, so the whole Slack entry is restated here.
      */
      (lib.mkIf (ai.opencode.enable && cfg.slack.enable) {
        programs.opencode.settings.mcp.slack = {
          type = "remote";
          url = slackUrl;
          oauth.clientId = slackClaudeClientId;
        };
      })

      (lib.mkIf cfg.home-assistant.enable {
        sops.secrets."home-assistant/mcp_token" = { };
      })
    ]
  );
}
