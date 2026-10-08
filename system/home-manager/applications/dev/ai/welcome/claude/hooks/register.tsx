/**
 * Claude Code start screen. Its logo can't be replaced, so the shared
 * wordmark and greeting are drawn in the band above the prompt, until the
 * first prompt, slash command or `!` command lands in the transcript
 * (`prompt.submit` misses the last two).
 *
 * The hook sandbox has no Node and no local time zone, so the clock, host and
 * branch come from `date`, `uname` and `git`, read once at session start.
 *
 * `banner.ts` and `identity.ts` are copied beside this file at build time
 * (see `../../default.nix`).
 */
import { atom, read, update } from "claude-code";
import type { EngineInterface, Register } from "claude-code";
import type { Welcome } from "../types";
import {
  dateline,
  gradients,
  greeting,
  mocha,
  project,
  shade,
  signature,
  wordmark,
  wordmarkWidth,
} from "./banner";

const welcome = atom({ plugin: "welcome", key: "welcome" } as const, null);
const isGreeted = atom({ plugin: "welcome", key: "isGreeted" } as const, false);

const gutter = 3;
const minimumTextWidth = 30;

async function lookAround($: EngineInterface, cwd: string): Promise<Welcome> {
  const [clock, host, branch, home] = await Promise.all([
    $.process.run(["date", "+%Y %m %d %H %M"]),
    $.process.run(["uname", "-n"]),
    $.process.run(["git", "-C", cwd, "branch", "--show-current"]),
    $.env.get("HOME"),
  ]);
  const [year = 1970, month = 1, day = 1, hour = 0, minute = 0] = clock.stdout.trim().split(" ").map(Number);
  const branchName = branch.exitCode === 0 ? branch.stdout.trim() : "";
  const place = project(cwd, home ?? undefined);

  return {
    hour,
    date: dateline(new Date(year, month - 1, day, hour, minute)),
    where: signature(branchName ? `${place} \ue0a0 ${branchName}` : place, host.stdout.trim()),
  };
}

export const register: Register = (on) => {
  on("session.start", async ($, e, next) => {
    if (e.isInteractive) {
      const found = await lookAround($, e.cwd);
      await update($, welcome, () => found);
    }

    return next(e);
  });

  on("session.append", async ($, e, next) => {
    const isFirstMove = e.agentId === undefined && (e.door === "prompt" || e.door === "command");
    if (isFirstMove) await update($, isGreeted, () => true);

    return next(e);
  });

  on("ui.render", { component: "AbovePrompt" }, async ($, e, next) => {
    const [state, greeted] = await Promise.all([read($, welcome), read($, isGreeted)]);

    if (state === null || greeted || e.props.hasSurvey || e.props.view.agentId !== undefined) {
      return next(e);
    }

    const { Box, Text } = $.ui.resolve(e);
    const isWide = e.props.bodyColumns >= wordmarkWidth + gutter + minimumTextWidth;
    const lines = [
      <Text bold color={gradients.claude.at(-1)} wrap="truncate-end">
        {greeting(state.hour)}
      </Text>,
      <Text color={mocha.subtext0} wrap="truncate-end">
        {state.date}
      </Text>,
      <Text color={mocha.overlay1} wrap="truncate-end">
        {state.where}
      </Text>,
    ];

    return (
      <Box flexDirection="column">
        {wordmark.map((art, row) => (
          <Box flexDirection="row">
            {isWide && (
              <Text>
                {shade(art, gradients.claude).map(({ text, color }) => (
                  <Text color={color}>{text}</Text>
                ))}
                {" ".repeat(wordmarkWidth - [...art].length + gutter)}
              </Text>
            )}
            {lines[row]}
          </Box>
        ))}
      </Box>
    );
  });
};
