import { execFile } from "child_process";
import fs from "fs";
import path from "path";
import { promisify } from "util";
import { PathSize, ScanResult, CategoryDefinition } from "./types";
import { detectPlatform } from "./platform";
import { hasTool } from "./tool-detect";
import { finiteBytes, parseDuKilobytes } from "./bytes";

const execFileP = promisify(execFile);

/** Resolve a path like "~/.npm" against the OS home directory. */
export function homePath(...parts: string[]): string {
  const home = process.env.HOME || process.env.USERPROFILE || "";
  return path.join(home, ...parts);
}

function execStdout(err: unknown): string {
  if (err && typeof err === "object" && "stdout" in err) {
    const stdout = (err as { stdout?: unknown }).stdout;
    if (typeof stdout === "string") return stdout;
    if (Buffer.isBuffer(stdout)) return stdout.toString("utf8");
  }
  return "";
}

function allocatedBytes(st: fs.Stats): number {
  if (typeof st.blocks === "number" && st.blocks > 0) return st.blocks * 512;
  return st.size > 0 ? st.size : 0;
}

/**
 * Drop paths nested under another path in the same list so summing sizes
 * does not double-count.
 */
export function dedupeNestedPaths(paths: string[]): string[] {
  const resolved = [
    ...new Set(
      paths.filter(Boolean).map((p) => {
        const r = path.resolve(p);
        return process.platform === "win32" ? r.toLowerCase() : r;
      })
    ),
  ].sort((a, b) => a.length - b.length);

  const kept: string[] = [];
  for (const p of resolved) {
    const nested = kept.some((parent) => p === parent || p.startsWith(parent + path.sep));
    if (!nested) kept.push(p);
  }
  return kept;
}

/**
 * Size a single path in bytes using allocated disk usage (not apparent size).
 * Unix: `du -sk` (stdout is used even when du exits non-zero on permission errors).
 * Fallback / Windows: Node walk with lstat, skipping symlinks.
 */
export async function sizeOfPath(p: string): Promise<number> {
  if (!p) return 0;
  try {
    fs.lstatSync(p);
  } catch {
    return 0;
  }

  if (process.platform !== "win32") {
    try {
      const { stdout } = await execFileP("du", ["-sk", p], { maxBuffer: 1024 * 1024 });
      const k = parseDuKilobytes(stdout);
      if (k != null) return k * 1024;
    } catch (err) {
      const k = parseDuKilobytes(execStdout(err));
      if (k != null) return k * 1024;
    }
  }

  return walkSize(p);
}

/** Recursive directory size in allocated bytes. Does not follow symlinks. */
export function walkSize(root: string): number {
  let total = 0;
  const stack: string[] = [root];
  const seen = new Set<string>();

  while (stack.length) {
    const current = stack.pop()!;
    let st: fs.Stats;
    try {
      st = fs.lstatSync(current);
    } catch {
      continue;
    }

    if (st.isSymbolicLink()) continue;

    if (!st.isDirectory()) {
      total += allocatedBytes(st);
      continue;
    }

    const resolved = path.resolve(current);
    if (seen.has(resolved)) continue;
    seen.add(resolved);
    if (st.dev && st.ino) {
      const id = `${st.dev}:${st.ino}`;
      if (seen.has(id)) continue;
      seen.add(id);
    }

    total += allocatedBytes(st);

    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (entry.name === "." || entry.name === "..") continue;
      stack.push(path.join(current, entry.name));
    }
  }

  return total;
}

export async function sumPathSizes(paths: string[]): Promise<{ paths: PathSize[]; totalSizeBytes: number }> {
  const unique = dedupeNestedPaths(paths);
  const sized: PathSize[] = await mapWithConcurrency(unique, 4, async (p) => {
    const sizeBytes = await sizeOfPath(p);
    return { path: p, sizeBytes, exists: pathExists(p) };
  });
  const totalSizeBytes = sized.reduce((acc, p) => acc + finiteBytes(p.sizeBytes), 0);
  return { paths: sized, totalSizeBytes };
}

export function pathExists(p: string): boolean {
  try {
    fs.lstatSync(p);
    return true;
  } catch {
    return false;
  }
}

export async function mapWithConcurrency<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;

  async function worker() {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i]);
    }
  }

  const workers = Array.from({ length: Math.min(limit, Math.max(items.length, 0)) }, () => worker());
  await Promise.all(workers);
  return results;
}

/** Scans every applicable category and returns sizes for the current platform. */
export async function scanCategories(categories: CategoryDefinition[]): Promise<ScanResult[]> {
  const platform = detectPlatform();

  const results = await mapWithConcurrency(categories, 6, async (category) => {
    const applicable = category.platforms.includes(platform);

    if (!applicable) {
      return {
        category,
        paths: [],
        totalSizeBytes: 0,
        applicable: false,
        detected: false,
      };
    }

    let toolMissing = false;
    if (category.toolRequirement && !hasTool(category.toolRequirement)) {
      toolMissing = true;
    }

    const rawPaths = await category.getPaths();
    const { paths, totalSizeBytes: pathTotal } = await sumPathSizes(rawPaths);

    let totalSizeBytes = pathTotal;
    if (category.getSizeBytes) {
      try {
        totalSizeBytes = finiteBytes(await category.getSizeBytes());
      } catch {
        totalSizeBytes = pathTotal;
      }
    }

    const detected =
      !toolMissing &&
      (paths.some((p) => p.exists && p.sizeBytes > 0) ||
        totalSizeBytes > 0 ||
        (rawPaths.length === 0 && category.cleanCommands().length > 0));

    return { category, paths, totalSizeBytes, applicable: true, detected, toolMissing };
  });

  return results;
}
