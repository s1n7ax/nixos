/**
 * Persistent per-directory model selection.
 *
 * Records every explicit model selection (/model, cycle keys) into
 * model-memory.json in the agent dir, keyed by cwd, plus a global
 * lastUsed entry. On session startup and /clear (reason "new") the
 * remembered model for the current directory is re-applied, falling back
 * to lastUsed in directories never seen before. Resume and fork are left
 * to Pi's own transcript restore.
 *
 * A remembered model that no longer exists (or has no auth) is skipped,
 * leaving Pi's built-in initial-model fallback untouched. The guard flag
 * keeps the extension's own setModel call from being recorded, so an
 * auto-applied lastUsed does not pin a fresh directory.
 */
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface MemoryEntry {
  provider: string;
  modelId: string;
}

interface Memory {
  lastUsed?: MemoryEntry;
  directories: Record<string, MemoryEntry>;
}

/** Mirror pi's normalizePath tilde expansion for PI_CODING_AGENT_DIR. */
function expandTilde(path: string): string {
  if (path === "~") return homedir();
  if (path.startsWith("~/")) return join(homedir(), path.slice(2));
  return path;
}

const agentDir = process.env.PI_CODING_AGENT_DIR
  ? expandTilde(process.env.PI_CODING_AGENT_DIR)
  : join(homedir(), ".pi", "agent");
const memoryPath = join(agentDir, "model-memory.json");

/** Only entries with a string provider and modelId are usable. */
function toEntry(value: unknown): MemoryEntry | undefined {
  if (typeof value !== "object" || value === null) return undefined;
  const { provider, modelId } = value as Record<string, unknown>;
  if (typeof provider !== "string" || typeof modelId !== "string") return undefined;
  return { provider, modelId };
}

/** Missing or malformed memory is treated as empty. */
function loadMemory(): Memory {
  try {
    if (!existsSync(memoryPath)) return { directories: {} };
    const parsed = JSON.parse(readFileSync(memoryPath, "utf8"));
    if (typeof parsed !== "object" || parsed === null) return { directories: {} };
    const directories: Record<string, MemoryEntry> = {};
    if (typeof parsed.directories === "object" && parsed.directories !== null) {
      for (const [cwd, value] of Object.entries(parsed.directories)) {
        const entry = toEntry(value);
        if (entry) directories[cwd] = entry;
      }
    }
    return { lastUsed: toEntry(parsed.lastUsed), directories };
  } catch {
    return { directories: {} };
  }
}

/** Write tmp + rename so a crash mid-write cannot corrupt the file. */
function saveMemory(memory: Memory): void {
  const tmpPath = `${memoryPath}.tmp`;
  writeFileSync(tmpPath, `${JSON.stringify(memory, null, 2)}\n`);
  renameSync(tmpPath, memoryPath);
}

export default function (pi: ExtensionAPI) {
  let applyingMemory = false;

  pi.on("model_select", (event, ctx) => {
    if (applyingMemory) return;
    if (event.source !== "set" && event.source !== "cycle") return;

    const entry: MemoryEntry = { provider: event.model.provider, modelId: event.model.id };
    // Read-modify-write: merge into the on-disk state so concurrent Pi
    // instances degrade to last-write-wins per entry, not per file.
    const memory = loadMemory();
    memory.directories[ctx.cwd] = entry;
    memory.lastUsed = entry;
    try {
      saveMemory(memory);
    } catch {
      // A persistence failure must not break model selection itself.
    }
  });

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "startup" && event.reason !== "new") return;

    const memory = loadMemory();
    const entry = memory.directories[ctx.cwd] ?? memory.lastUsed;
    if (!entry) return;

    const model = ctx.modelRegistry.find(entry.provider, entry.modelId);
    if (!model) return;

    // Already the active model: applying again would only append a
    // redundant model_change entry to the session transcript.
    if (ctx.model?.provider === entry.provider && ctx.model?.id === entry.modelId) return;

    applyingMemory = true;
    try {
      // false (no auth) or a rejected promise (auth check failed): leave
      // pi's built-in initial-model fallback untouched.
      await pi.setModel(model);
    } catch {
      // Unavailable remembered models get pi's default handling.
    } finally {
      applyingMemory = false;
    }
  });
}
