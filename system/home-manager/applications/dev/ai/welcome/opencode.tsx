/** @jsxImportSource @opentui/solid */
/**
 * OpenCode start screen: replaces the logo on the home route (the
 * `home_logo` slot) with the shared wordmark and greeting. OpenCode already
 * shows the directory, branch and version in its footer, so they are left out.
 *
 * `banner.ts` and `identity.ts` are copied beside this file at build time
 * (see `default.nix`).
 */
import { hostname } from "node:os";
import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui";
import { dateline, gradients, greeting, mocha, shade, signature, wordmark } from "./banner";

const gutter = 3;

function Welcome() {
  const now = new Date();

  return (
    <box flexDirection="row">
      <box flexDirection="column" marginRight={gutter}>
        {wordmark.map((line) => (
          <text>
            {shade(line, gradients.opencode).map(({ text, color }) => (
              <span style={{ fg: color }}>{text}</span>
            ))}
          </text>
        ))}
      </box>
      <box flexDirection="column">
        <text fg={gradients.opencode.at(-1)}>
          <b>{greeting(now.getHours())}</b>
        </text>
        <text fg={mocha.subtext0}>{dateline(now)}</text>
        <text fg={mocha.overlay1}>{signature("opencode", hostname())}</text>
      </box>
    </box>
  );
}

const tui: TuiPlugin = async (api) => {
  api.slots.register({
    order: 100,
    slots: {
      home_logo() {
        return <Welcome />;
      },
    },
  });
};

const plugin: TuiPluginModule & { id: string } = { id: "welcome", tui };

export default plugin;
