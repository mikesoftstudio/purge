import { execFileSync } from "child_process";
import { ToolInfo, Platform } from "./types";

const TOOLS = ["brew", "npm", "pnpm", "yarn", "pip3", "pod", "flutter", "dart", "gradle", "docker", "go", "cargo", "xcodebuild", "xcrun", "sdkmanager"];

// Probing binaries spawns subprocesses; on a long-running server the result is
// stable, so memoize it to keep scans fast.
const toolCache = new Map<string, boolean>();
const versionCache = new Map<string, string | null>();

/**
 * Returns `true` when the given binary exists on PATH.
 * Cross-platform: uses `where` on Windows, `command -v` on Unix.
 */
export function hasTool(name: string): boolean {
  if (!name) return false;
  const cached = toolCache.get(name);
  if (cached !== undefined) return cached;

  let found = false;
  if (process.platform === "win32") {
    try {
      execFileSync("where", [name], { stdio: "ignore" });
      found = true;
    } catch {
      found = false;
    }
  } else {
    try {
      execFileSync("sh", ["-c", `command -v "${name}"`], { stdio: "ignore" });
      found = true;
    } catch {
      found = false;
    }
  }
  toolCache.set(name, found);
  return found;
}

function versionArgs(name: string): string[] {
  // xcodebuild takes `-version`, unlike most tools that accept `--version`.
  return name === "xcodebuild" ? ["-version"] : ["--version"];
}

export function toolVersion(name: string): string | undefined {
  if (versionCache.has(name)) return versionCache.get(name) ?? undefined;

  let version: string | null = null;
  try {
    version = execFileSync(name, versionArgs(name), { encoding: "utf8", timeout: 5000, stdio: ["ignore", "pipe", "pipe"] })
      .split("\n")[0]
      .trim()
      .slice(0, 80);
  } catch {
    version = null;
  }
  versionCache.set(name, version);
  return version ?? undefined;
}

/** Invalidate memoized results (used in tests). */
export function resetToolCache(): void {
  toolCache.clear();
  versionCache.clear();
}

/**
 * Reports which known toolchains are installed on the current platform.
 */
export function detectTools(platform: Platform): ToolInfo[] {
  return TOOLS.map((name) => ({
    name,
    installed: hasTool(name),
    version: hasTool(name) ? toolVersion(name) : undefined,
  }));
}