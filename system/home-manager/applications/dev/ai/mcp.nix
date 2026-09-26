{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = import ./common.nix { };
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
    // lib.optionalAttrs cfg.home-assistant.enable {
      home-assistant.command = "${homeAssistantMcp}";
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
        programs.claude-code.mcpServers = servers;
      })

      (lib.mkIf cfg.home-assistant.enable {
        sops.secrets."home-assistant/mcp_token" = { };
      })
    ]
  );
}
