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

const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const memoryPath = join(agentDir, "model-memory.json");

/** Missing or malformed memory is treated as empty. */
function loadMemory(): Memory {
  try {
    if (!existsSync(memoryPath)) return { directories: {} };
    const parsed = JSON.parse(readFileSync(memoryPath, "utf8"));
    if (typeof parsed !== "object" || parsed === null) return { directories: {} };
    return {
      lastUsed: parsed.lastUsed,
      directories: typeof parsed.directories === "object" && parsed.directories !== null
        ? parsed.directories
        : {},
    };
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
    saveMemory(memory);
  });

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "startup" && event.reason !== "new") return;

    const memory = loadMemory();
    const entry = memory.directories[ctx.cwd] ?? memory.lastUsed;
    if (!entry) return;

    const model = ctx.modelRegistry.find(entry.provider, entry.modelId);
    if (!model) return;

    applyingMemory = true;
    try {
      await pi.setModel(model);
    } finally {
      applyingMemory = false;
    }
  });
}
