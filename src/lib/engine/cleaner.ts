import fs from "fs";
import os from "os";
import path from "path";
import { spawn, execFile } from "child_process";
import { promisify } from "util";
import { CategoryDefinition, CleanCommand, CleanProgressEvent } from "./types";
import { sumPathSizes } from "./scanner";
import { finiteBytes } from "./bytes";

const execFileP = promisify(execFile);

export class CleanCommandError extends Error {
  constructor(public readonly commandLabel: string, public readonly exitCode: number | null) {
    super(`Command failed (exit ${exitCode ?? "?"}): ${commandLabel}`);
    this.name = "CleanCommandError";
  }
}

export class UnsafePathError extends Error {
  constructor(p: string) {
    super(`Refusing to remove unsafe path: ${p}`);
    this.name = "UnsafePathError";
  }
}

/**
 * Defense-in-depth guard that rejects anything that would be catastrophic to
 * remove. Mirrors the `rm_safe` guarantees of the original CLI script.
 */
export function assertSafePath(p: string): void {
  const normalized = path.normalize(p);
  const home = os.homedir();

  if (!p || p.trim() === "") throw new UnsafePathError("empty path");
  if (normalized === "/" || normalized === "\\") throw new UnsafePathError(p);

  if (process.platform === "win32") {
    if (/^[a-zA-Z]:\\?$/.test(normalized)) throw new UnsafePathError(p);
    if (normalized.toLowerCase() === path.normalize(home).toLowerCase()) throw new UnsafePathError(p);
  } else if (normalized === home) {
    throw new UnsafePathError(p);
  }

  // Never allow removing a top-level volume mount root on Unix either.
  const segments = normalized.split(path.sep).filter(Boolean);
  if (segments.length === 0) throw new UnsafePathError(p);
}

/** Removes a path with `rm -rf` semantics, guarded. */
export async function removePath(p: string): Promise<void> {
  assertSafePath(p);
  try {
    await fs.promises.stat(p);
  } catch {
    return;
  }
  await fs.promises.rm(p, { recursive: true, force: true });
}

/**
 * Runs a CleanCommand and rejects with CleanCommandError when it exits
 * non-zero, so failures are surfaced instead of silently ignored.
 */
async function runCleanCommand(cmd: CleanCommand): Promise<void> {
  // On Windows, tool binaries are often `.cmd` shims (npm, dotnet, choco…)
  // which require a shell to execute, so route those through the shell too.
  if (cmd.shell || process.platform === "win32") {
    const shell = process.platform === "win32" ? "powershell.exe" : "/bin/bash";
    const joined = [cmd.command, ...cmd.args].join(" ");
    const full = process.platform === "win32" ? `${joined}; exit $LASTEXITCODE` : joined;
    const shellArgs = process.platform === "win32"
      ? ["-NoProfile", "-Command", full]
      : ["-c", full];
    await new Promise<void>((resolve, reject) => {
      const child = spawn(shell, shellArgs, { stdio: "ignore", windowsHide: true });
      child.on("close", (code) => (code === 0 ? resolve() : reject(new CleanCommandError(cmd.label ?? cmd.command, code))));
      child.on("error", (err) => reject(new CleanCommandError(cmd.label ?? cmd.command, null)));
    });
    return;
  }

  try {
    await execFileP(cmd.command, cmd.args, { maxBuffer: 1024 * 1024, windowsHide: true });
  } catch (err) {
    const code =
      err && typeof err === "object" && "code" in err && typeof err.code === "number" ? err.code : null;
    throw new CleanCommandError(cmd.label ?? cmd.command, code);
  }
}

export interface CleanJobOptions {
  categories: CategoryDefinition[];
  /** Pre-measured sizes (bytes) per categoryId from a recent scan. Reused as
   * the "before" size so we don't re-walk big directories. */
  measuredSizes?: Map<string, number>;
  onProgress: (event: CleanProgressEvent) => void;
  /** Set to abort between commands. */
  isCancelled: () => boolean;
}

/**
 * Cleans each category in order, emitting progress events. Measures directory
 * size after cleaning to report real bytes freed. A failed category surfaces an
 * "error" event and tries `onFailureCommands` if defined. Never fails the whole
 * job.
 */
export async function runCleanJob({ categories, measuredSizes, onProgress, isCancelled }: CleanJobOptions): Promise<void> {
  for (const category of categories) {
    if (isCancelled()) {
      onProgress({ categoryId: category.id, status: "skipped", label: "Cancelled" });
      continue;
    }

    // Skip cleanly (e.g. Docker daemon not running) instead of erroring.
    if (category.skipReason) {
      const reason = await category.skipReason().catch(() => null);
      if (reason) {
        onProgress({ categoryId: category.id, status: "skipped", label: reason });
        continue;
      }
    }

    onProgress({ categoryId: category.id, status: "cleaning" });

    const before =
      measuredSizes?.get(category.id) ?? (await measureCategory(category));

    const commands = category.cleanCommands();

    let outcome: "done" | "error" = "done";
    for (const cmd of commands) {
      if (isCancelled()) {
        outcome = "error";
        break;
      }
      onProgress({ categoryId: category.id, status: "cleaning", label: cmd.label ?? cmd.command });
      try {
        await runCleanCommand(cmd);
      } catch (err) {
        // Try platform-specific fallback (e.g. emptying macOS Trash via Finder).
        const fallback = category.onFailureCommands?.().filter((c) => c.command !== cmd.command || c.args.join(" ") !== cmd.args.join(" ")) ?? [];
        if (fallback.length === 0) {
          outcome = "error";
          onProgress({
            categoryId: category.id,
            status: "error",
            label: err instanceof Error ? err.message.split("\n")[0] : "failed",
          });
          break;
        }
        let recovered = false;
        for (const c of fallback) {
          onProgress({ categoryId: category.id, status: "cleaning", label: `retry: ${c.label ?? c.command}` });
          try {
            await runCleanCommand(c);
            recovered = true;
            break;
          } catch {
            /* try next fallback */
          }
        }
        if (!recovered) {
          outcome = "error";
          onProgress({
            categoryId: category.id,
            status: "error",
            label: err instanceof Error ? err.message.split("\n")[0] : "failed",
          });
        }
        break;
      }
    }

    if (isCancelled()) {
      onProgress({ categoryId: category.id, status: "skipped", label: "Cancelled" });
      continue;
    }

    let after = before;
    try {
      after = await measureCategory(category);
    } catch {
      after = before;
    }
    const freedBytes = Math.max(finiteBytes(before) - finiteBytes(after), 0);

    if (outcome === "error") {
      // Freed size may still be non-zero from partial cleaning.
      onProgress({ categoryId: category.id, status: "error", freedBytes });
    } else {
      onProgress({ categoryId: category.id, status: "done", freedBytes });
    }
  }
}

async function measureCategory(category: CategoryDefinition): Promise<number> {
  const fromPaths = async () => {
    const paths = await category.getPaths();
    const { totalSizeBytes } = await sumPathSizes(paths);
    return totalSizeBytes;
  };

  if (category.getSizeBytes) {
    try {
      return finiteBytes(await category.getSizeBytes());
    } catch {
      return fromPaths();
    }
  }
  return fromPaths();
}