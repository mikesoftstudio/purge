export type Platform = "macos" | "linux" | "windows" | "android" | "ios";

export type SafetyTier = "safe" | "moderate" | "advanced";

export type CategoryStatus = "detected" | "skipped" | "cleaning" | "done" | "cancelled" | "error";

export interface CleanCommand {
  /** Executable name or absolute path (e.g. "npm", "docker", "rm"). */
  command: string;
  /** Arguments passed to the executable. */
  args: string[];
  /** Run through a shell instead of spawn (needed for && chains / wildcards). */
  shell?: boolean;
  /** Human-readable label shown while the command runs. */
  label?: string;
}

export interface CategoryDefinition {
  id: string;
  name: string;
  description: string;
  safety: SafetyTier;
  tradeoff: string;
  /** Platforms this category applies to (returned for others but never
   * recommended, and excluded from cleaning). */
  platforms: Platform[];
  /** Name of the binary that must be installed for this category to apply. */
  toolRequirement?: string;
  /** Returns the regenerable paths for the current platform. */
  getPaths: () => string[] | Promise<string[]>;
  /** Optional tool-provided sizing (e.g. `docker system df`) when the size
   * isn't a simple sum of directories. */
  getSizeBytes?: () => Promise<number>;
  /** Returns the commands used to clean this category on the current platform. */
  cleanCommands: () => CleanCommand[];
  /** Commands attempted only if a primary clean command fails (e.g. emptying
   * macOS Trash via Finder when direct rm is blocked by TCC). */
  onFailureCommands?: () => CleanCommand[];
  /** When non-null, the category is skipped (reported as skipped) with this
   * reason instead of being cleaned — e.g. Docker daemon not running. */
  skipReason?: () => Promise<string | null>;
}

export interface PathSize {
  path: string;
  sizeBytes: number;
  exists: boolean;
}

export interface ScanResult {
  category: CategoryDefinition;
  paths: PathSize[];
  totalSizeBytes: number;
  applicable: boolean;
  /** true when the sized paths actually exist on disk. */
  detected: boolean;
  /** set when applicable but the required tool is missing. */
  toolMissing?: boolean;
}

export interface ToolInfo {
  name: string;
  installed: boolean;
  version?: string;
}

export interface DiskInfo {
  totalBytes: number;
  usedBytes: number;
  freeBytes: number;
  home: string;
  filesystem: string;
}

export interface CleanProgressEvent {
  categoryId: string;
  status: "cleaning" | "done" | "error" | "skipped";
  label?: string;
  freedBytes?: number;
}

export interface CleanSummary {
  totalFreedBytes: number;
  cleaned: string[];
  skipped: string[];
  errored: string[];
  startedAt: number;
  finishedAt: number;
}