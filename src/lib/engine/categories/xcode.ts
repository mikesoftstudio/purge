import fs from "fs";
import path from "path";
import { execFile } from "child_process";
import { promisify } from "util";
import { CategoryDefinition } from "../types";
import { homePath } from "../scanner";

const execFileP = promisify(execFile);

const derivedDataPath = homePath("Library", "Developer", "Xcode", "DerivedData");
const deviceSupportPath = homePath("Library", "Developer", "Xcode", "iOS DeviceSupport");
const simulatorCachePath = homePath("Library", "Developer", "CoreSimulator", "Caches");
const simulatorDevicesPath = homePath("Library", "Developer", "CoreSimulator", "Devices");

/** Keep the newest DeviceSupport folder; only older ones are deleted. */
function oldDeviceSupportPaths(): string[] {
  try {
    const entries = fs
      .readdirSync(deviceSupportPath, { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => {
        const full = path.join(deviceSupportPath, e.name);
        let mtime = 0;
        try {
          mtime = fs.statSync(full).mtimeMs;
        } catch {
          /* unreadable */
        }
        return { full, mtime };
      })
      .sort((a, b) => b.mtime - a.mtime);
    return entries.slice(1).map((e) => e.full);
  } catch {
    return [];
  }
}

async function unavailableSimulatorPaths(): Promise<string[]> {
  try {
    const { stdout } = await execFileP("xcrun", ["simctl", "list", "devices", "-j"], {
      timeout: 20000,
      maxBuffer: 10 * 1024 * 1024,
    });
    const data = JSON.parse(stdout) as {
      devices?: Record<string, Array<{ udid?: string; isAvailable?: boolean }>>;
    };
    const ids: string[] = [];
    for (const list of Object.values(data.devices ?? {})) {
      for (const device of list) {
        if (device.isAvailable === false && device.udid) ids.push(device.udid);
      }
    }
    return ids
      .map((id) => path.join(simulatorDevicesPath, id))
      .filter((p) => {
        try {
          fs.lstatSync(p);
          return true;
        } catch {
          return false;
        }
      });
  } catch {
    return [];
  }
}

export const xcodeDerivedDataCategory: CategoryDefinition = {
  id: "xcode-deriveddata",
  name: "Xcode DerivedData",
  description: "Build products, indexes and logs created by Xcode for every project you open.",
  safety: "safe",
  tradeoff: "Your first build after cleaning will be slower while Xcode regenerates everything.",
  platforms: ["macos"],
  toolRequirement: "xcodebuild",
  getPaths: () => [derivedDataPath, homePath("Library", "Caches", "com.apple.dt.Xcode")],
  cleanCommands: () => [
    {
      command: "rm",
      args: ["-rf", derivedDataPath],
      shell: true,
      label: "remove DerivedData",
    },
    {
      command: "rm",
      args: ["-rf", homePath("Library", "Caches", "com.apple.dt.Xcode")],
      shell: true,
      label: "remove Xcode app caches",
    },
  ],
};

export const xcodeDeviceSupportCategory: CategoryDefinition = {
  id: "xcode-devicesupport",
  name: "Old iOS DeviceSupport",
  description: "Debug symbols for past iOS versions on devices you have plugged in.",
  safety: "moderate",
  tradeoff: "Debugging an old iOS device may need you to re-plug it once to rebuild symbols.",
  platforms: ["macos"],
  toolRequirement: "xcodebuild",
  getPaths: oldDeviceSupportPaths,
  cleanCommands: () => [
    {
      command: "bash",
      args: ["-c", `cd "${deviceSupportPath}" 2>/dev/null && ls -dt */ | tail -n +2 | xargs -I{} rm -rf -- "${deviceSupportPath}/{}"`],
      label: "keep only the most recent device support",
    },
  ],
};

export const xcodeSimulatorCachesCategory: CategoryDefinition = {
  id: "xcode-simulator-caches",
  name: "Simulator Caches",
  description: "iOS Simulator dyld and app caches.",
  safety: "safe",
  tradeoff: "Simulators take slightly longer to launch once.",
  platforms: ["macos"],
  toolRequirement: "xcrun",
  getPaths: () => [simulatorCachePath],
  cleanCommands: () => [{ command: "rm", args: ["-rf", simulatorCachePath], label: "remove CoreSimulator caches" }],
};

export const iosSimulatorsCategory: CategoryDefinition = {
  id: "ios-simulators",
  name: "Unused iOS Simulators",
  description: "Simulator devices Xcode no longer uses but keeps on disk.",
  safety: "moderate",
  tradeoff: "You may need to re-create a simulator if you switch iOS versions.",
  platforms: ["macos"],
  toolRequirement: "xcrun",
  getPaths: unavailableSimulatorPaths,
  cleanCommands: () => [{ command: "xcrun", args: ["simctl", "delete", "unavailable"], label: "xcrun simctl delete unavailable" }],
};
