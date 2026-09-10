import { execFileSync } from "child_process";
import { CategoryDefinition } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";

const platform = detectPlatform();

const pubCachePath = () => {
  if (platform === "windows") return process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\Pub\\Cache` : homePath("AppData", "Local", "Pub", "Cache");
  return homePath(".pub-cache");
};

/** Resolves <flutter-sdk>/bin/cache by following symlinks to the real SDK. */
function flutterSdkCachePath(): string {
  let bin: string | undefined;
  try {
    if (process.platform === "win32") {
      bin = execFileSync("where", ["flutter"], { encoding: "utf8", timeout: 5000 }).trim().split("\n")[0];
    } else {
      bin = execFileSync("sh", ["-c", "command -v flutter"], { encoding: "utf8", timeout: 5000 }).trim();
    }
  } catch {
    return "";
  }
  if (!bin) return "";

  let real = bin;
  try {
    real = execFileSync("python3", ["-c", "import os,sys;print(os.path.realpath(sys.argv[1]))", bin], { encoding: "utf8", timeout: 5000 }).trim();
  } catch {
    /* python3 not available — use the raw path */
  }

  const parts = real.split(/[\\/]+/).filter(Boolean);
  const sdk = parts.slice(0, -2).join("/");
  return sdk ? `${sdk}/bin/cache` : "";
}

export const flutterCategory: CategoryDefinition = {
  id: "flutter-pub-cache",
  name: "Dart / Flutter Pub Cache",
  description: "Downloaded Dart packages used by pub get.",
  safety: "safe",
  tradeoff: "Packages are re-downloaded on the next pub get / flutter run.",
  platforms: ["macos", "linux", "windows", "android"],
  toolRequirement: "flutter",
  getPaths: () => [pubCachePath()],
  cleanCommands: () => [{ command: "rm", args: ["-rf", pubCachePath()], label: "remove pub cache" }],
};

export const flutterSdkCacheCategory: CategoryDefinition = {
  id: "flutter-sdk-cache",
  name: "Flutter Engine Cache",
  description: "Pre-built Flutter engine artifacts inside the SDK.",
  safety: "moderate",
  tradeoff: "The next flutter command re-downloads ~1–2 GB of engine artifacts.",
  platforms: ["macos", "linux", "windows", "android"],
  toolRequirement: "flutter",
  getPaths: () => {
    const p = flutterSdkCachePath();
    return p ? [p] : [];
  },
  cleanCommands: () => {
    const p = flutterSdkCachePath();
    return p ? [{ command: "rm", args: ["-rf", p], label: "remove Flutter engine cache" }] : [];
  },
};