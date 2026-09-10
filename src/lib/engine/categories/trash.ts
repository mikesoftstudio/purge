import { execFile } from "child_process";
import { promisify } from "util";
import { CategoryDefinition } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";
import { finiteBytes } from "../bytes";

const execFileP = promisify(execFile);
const platform = detectPlatform();

async function recycleBinBytes(): Promise<number> {
  try {
    const { stdout } = await execFileP(
      "powershell.exe",
      [
        "-NoProfile",
        "-Command",
        "$ErrorActionPreference='SilentlyContinue'; $n=0; $s=New-Object -ComObject Shell.Application; foreach($i in $s.NameSpace(10).Items()){ $n += [int64]$i.Size }; $n",
      ],
      { timeout: 15000, maxBuffer: 1024 * 1024 }
    );
    return finiteBytes(Number.parseInt(stdout.trim(), 10));
  } catch {
    return 0;
  }
}

async function macTrashBytes(): Promise<number> {
  try {
    const { stdout } = await execFileP(
      "osascript",
      ["-e", 'tell application "Finder" to get size of trash'],
      { timeout: 15000 }
    );
    const n = Number.parseInt(stdout.trim(), 10);
    if (Number.isFinite(n) && n >= 0) return n;
  } catch {
    /* fall back to path sizing */
  }
  throw new Error("finder trash size unavailable");
}

export const trashCategory: CategoryDefinition = {
  id: "trash",
  name: "Trash",
  description: "Files you have moved to Trash / Recycle Bin.",
  safety: "safe",
  tradeoff: "Items in the Trash are permanently deleted and cannot be restored.",
  platforms: ["macos", "linux", "windows", "android"],
  getPaths: () => {
    if (platform === "windows") return [];
    if (platform === "macos") return [homePath(".Trash"), homePath(".local", "share", "Trash")];
    return [homePath(".local", "share", "Trash")];
  },
  getSizeBytes: platform === "windows" ? recycleBinBytes : platform === "macos" ? macTrashBytes : undefined,
  cleanCommands: () => {
    if (platform === "windows") {
      return [{ command: "Clear-RecycleBin", args: ["-Force"], shell: true, label: "Clear-RecycleBin -Force" }];
    }
    if (platform === "macos") {
      return [
        { command: "rm", args: ["-rf", homePath(".Trash")], shell: true, label: "empty Trash" },
        { command: "rm", args: ["-rf", homePath(".local", "share", "Trash")], shell: true, label: "empty XDG Trash" },
      ];
    }
    return [{ command: "rm", args: ["-rf", homePath(".local", "share", "Trash")], shell: true, label: "empty Trash" }];
  },
  onFailureCommands: () => {
    // macOS TCC often blocks direct ~/.Trash access — fall back to Finder.
    if (platform === "macos") {
      return [
        {
          command: "osascript",
          args: ["-e", 'tell application "Finder" to empty trash'],
          label: "empty Trash via Finder",
        },
      ];
    }
    return [];
  },
};