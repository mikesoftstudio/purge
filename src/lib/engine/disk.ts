import { execFile } from "child_process";
import { promisify } from "util";
import os from "os";
import { DiskInfo } from "./types";
import { parseDfPosix } from "./bytes";

const execFileP = promisify(execFile);

/**
 * Queries the mounted volume that contains the home directory.
 * Unix: POSIX `df -kP` (no line wrapping, 1024-byte blocks).
 * Windows: PowerShell Get-PSDrive Used/Free (bytes).
 */
export async function getDiskInfo(): Promise<DiskInfo> {
  const home = os.homedir();

  if (process.platform === "win32") {
    return getDiskInfoWindows();
  }

  try {
    const { stdout } = await execFileP("df", ["-kP", home], { maxBuffer: 1024 * 1024 });
    const parsed = parseDfPosix(stdout);
    if (parsed) {
      return {
        totalBytes: parsed.totalBytes,
        usedBytes: parsed.usedBytes,
        freeBytes: parsed.freeBytes,
        home,
        filesystem: parsed.filesystem,
      };
    }
  } catch {
    /* fall through */
  }
  return { totalBytes: 0, usedBytes: 0, freeBytes: 0, home, filesystem: "unknown" };
}

async function getDiskInfoWindows(): Promise<DiskInfo> {
  const home = os.homedir();
  const drive = home.split("\\")[0] + "\\";
  try {
    const { stdout } = await execFileP(
      "powershell.exe",
      [
        "-NoProfile",
        "-Command",
        `Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq '${drive}' } | Select-Object -First 1 | ForEach-Object { "$($_.Used) $($_.Free) $($_.Root)" }`,
      ],
      { maxBuffer: 1024 * 1024, timeout: 15000 }
    );
    const [used, free] = stdout.trim().split(/\s+/).map(Number);
    if (Number.isFinite(used) && used >= 0 && Number.isFinite(free) && free >= 0) {
      return { totalBytes: used + free, usedBytes: used, freeBytes: free, home, filesystem: drive };
    }
  } catch {
    /* fall through */
  }
  return { totalBytes: 0, usedBytes: 0, freeBytes: 0, home, filesystem: drive };
}
