import { Platform } from "./engine/types";

const pretty: Record<Platform, string> = {
  macos: "macOS",
  linux: "Linux",
  windows: "Windows",
  android: "Android",
  ios: "iOS",
};

export function platformLabel(p: Platform): string {
  return pretty[p] ?? "Device";
}

/** Noun used in UI copy: "Scan my Mac", "Scan my PC", "Scan my device". */
export function deviceNoun(p: Platform): string {
  switch (p) {
    case "macos":
      return "Mac";
    case "windows":
      return "PC";
    default:
      return "device";
  }
}