/**
 * Pi start screen: replaces the built-in header (logo, version, key hints)
 * with the shared wordmark and greeting.
 *
 * The key hints are rebuilt with Pi's own `keyHint`, so they follow
 * ~/.pi/agent/keybindings.json, and `app.tools.expand` (ctrl+o) still swaps
 * them for the full list, as with the built-in header. Below 60 columns the
 * wordmark is dropped and only the text is drawn.
 */
import { hostname } from "node:os";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { keyHint, keyText, rawKeyHint, VERSION } from "@earendil-works/pi-coding-agent";
import { parseColor, truncateToWidth } from "@earendil-works/pi-tui";
import { dateline, gradients, greeting, shade, signature, wordmark, wordmarkWidth } from "./banner";

const gutter = 3;
const minimumWideWidth = 60;

class WelcomeHeader {
  private expanded = false;
  private readonly now = new Date();

  constructor(private readonly theme: Theme) {}

  setExpanded(expanded: boolean): void {
    this.expanded = expanded;
  }

  invalidate(): void {}

  render(width: number): string[] {
    const { theme } = this;
    const text = [
      theme.style(greeting(this.now.getHours()), { fg: parseColor(gradients.pi.at(-1)!), bold: true }),
      theme.fg("muted", dateline(this.now)),
      theme.fg("dim", signature(`pi v${VERSION}`, hostname())),
    ];
    const art = wordmark.map((line) =>
      shade(line, gradients.pi)
        .map(({ text: run, color }) => (color ? theme.style(run, { fg: parseColor(color) }) : run))
        .join(""),
    );
    const banner =
      width >= minimumWideWidth
        ? wordmark.map((line, row) => `${art[row]}${" ".repeat(wordmarkWidth - [...line].length + gutter)}${text[row]}`)
        : text;
    const hints = this.expanded ? this.allHints() : [this.compactHints()];

    return ["", ...banner, "", ...hints, ""].map((line) => truncateToWidth(line ? ` ${line}` : "", width));
  }

  private compactHints(): string {
    return [
      keyHint("app.interrupt", "interrupt"),
      keyHint("app.session.new", "new"),
      keyHint("app.model.select", "model"),
      rawKeyHint(`${keyText("app.clear")} twice`, "exit"),
      rawKeyHint("/", "commands"),
      rawKeyHint("!", "bash"),
      keyHint("app.tools.expand", "more"),
    ].join(this.theme.fg("muted", " · "));
  }

  private allHints(): string[] {
    return [
      keyHint("app.interrupt", "to interrupt"),
      keyHint("app.session.new", "to start a new session"),
      keyHint("app.clear", "to clear"),
      rawKeyHint(`${keyText("app.clear")} twice`, "to exit"),
      keyHint("app.suspend", "to suspend"),
      keyHint("app.thinking.cycle", "to cycle thinking level"),
      rawKeyHint(`${keyText("app.model.cycleForward")}/${keyText("app.model.cycleBackward")}`, "to cycle models"),
      keyHint("app.model.select", "to select model"),
      keyHint("app.tools.expand", "to expand tools"),
      keyHint("app.thinking.toggle", "to expand thinking"),
      keyHint("app.editor.external", "for external editor"),
      keyHint("tui.altScreen.halfPageUp", "to scroll up"),
      keyHint("tui.altScreen.halfPageDown", "to scroll down"),
      rawKeyHint("/", "for commands"),
      rawKeyHint("!", "to run bash"),
      rawKeyHint("!!", "to run bash (no context)"),
      keyHint("app.message.followUp", "to queue follow-up"),
      keyHint("app.clipboard.pasteImage", "to paste images"),
    ];
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode === "tui") ctx.ui.setHeader((_tui, theme) => new WelcomeHeader(theme));
  });
}
