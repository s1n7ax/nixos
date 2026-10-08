/**
  Personalized start screens for the AI agents: one wordmark, greeting and
  Catppuccin Mocha palette (banner.ts), drawn by each agent with its own UI
  API and tinted with its own gradient.

  - Pi: an extension replaces the startup header.
  - OpenCode: a TUI plugin replaces the home logo.
  - Claude Code: its logo can't be replaced, so a plugin of function hooks
    draws a band above the prompt until the first prompt.
  - Cursor CLI has no hook into its start screen, so it is left alone.

  Each runtime resolves relative imports from a file's real path, so the
  files are copied into one directory per agent rather than symlinked.
*/
{ pkgs, username }:
let
  /**
    The wordmark is rendered at build time so it follows `home.username`.
    pagga's shading glyph is blanked so only the letters are drawn.
  */
  identity =
    pkgs.runCommand "agent-welcome-identity.ts"
      {
        nativeBuildInputs = [
          pkgs.toilet
          pkgs.jq
        ];
      }
      ''
        toilet -f pagga ${pkgs.lib.escapeShellArg username} \
          | sed 's/░/ /g; s/^ //; s/ *$//' \
          | jq -R . \
          | jq -s --arg name ${pkgs.lib.escapeShellArg username} '{ name: $name, wordmark: . }' \
          > identity.json
        printf 'export const identity = %s;\n' "$(cat identity.json)" > $out
      '';

  /**
    Copies `src` to its own store path with banner.ts and identity.ts in
    `dir`, beside the module that imports them.
  */
  withBanner =
    name: src: dir:
    pkgs.runCommand name { } ''
      cp -r ${src} $out
      chmod -R u+w $out
      cp ${./banner.ts} $out/${dir}/banner.ts
      cp ${identity} $out/${dir}/identity.ts
    '';
in
{
  /** A plugin directory for `programs.claude-code.plugins`. */
  claudePlugin = withBanner "claude-welcome" ./claude "hooks";

  /** A directory extension: Pi loads its index.ts. */
  piExtension = withBanner "pi-welcome" (pkgs.writeTextDir "index.ts" (builtins.readFile ./pi.ts)) ".";

  /** A file path for tui.json's `plugin` list. */
  opencodePlugin = "${
    withBanner "opencode-welcome" (pkgs.writeTextDir "welcome.tsx" (builtins.readFile ./opencode.tsx)) "."
  }/welcome.tsx";
}
