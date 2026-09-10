import fs from "fs";
import { CategoryDefinition } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";

const platform = detectPlatform();

function systemPaths(): string[] {
  switch (platform) {
    case "macos":
      // ~/Library/Logs is a protected system dir on modern macOS (not removable),
      // so only target removable app caches.
      return [
        homePath("Library", "Caches", "com.apple.helpd"),
        homePath("Library", "Caches", "com.google.SoftwareUpdateAgent"),
        homePath("Library", "Caches", "org.carthage.CarthageKit"),
      ];
    case "android":
      return [
        homePath(".cache"),
        homePath(".termux", "cache"),
        homePath(".local", "share", "termux", "boot"),
      ];
    case "linux":
      return [
        homePath(".cache"),
      ];
    default:
      return [];
  }
}

function filterExisting(paths: string[]): string[] {
  return paths.filter((p) => {
    try {
      fs.lstatSync(p);
      return true;
    } catch {
      return false;
    }
  });
}

export const systemCategory: CategoryDefinition = {
  id: "system-caches",
  name: "System Caches & Logs",
  description: "Assorted removable application caches in your home directory.",
  safety: "safe",
  tradeoff: "Apps rebuild caches automatically as you use them.",
  platforms: ["macos", "linux", "android"],
  getPaths: () => filterExisting(systemPaths()),
  cleanCommands: () =>
    filterExisting(systemPaths()).map((p) => ({
      command: "rm",
      args: ["-rf", p],
      shell: true,
      label: `remove ${p.split("/").pop()}`,
    })),
};