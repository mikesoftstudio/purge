import type { Platform } from "@/lib/engine/types";

/**
 * Detect the client's OS from the browser. This runs in the browser and
 * returns what the user's machine is, regardless of where the server is.
 */
export function detectClientPlatform(): Platform {
  if (typeof navigator === "undefined") return "linux";

  const ua = navigator.userAgent.toLowerCase();
  const platform = (navigator.platform || "").toLowerCase();

  if (ua.includes("iphone") || ua.includes("ipad") || ua.includes("ipod")) return "ios";
  if (ua.includes("android")) return "android";
  if (platform.includes("win") || ua.includes("win")) return "windows";
  if (platform.includes("mac") || ua.includes("mac")) return "macos";
  return "linux";
}

export function clientPlatformLabel(p: Platform): string {
  switch (p) {
    case "macos": return "macOS";
    case "windows": return "Windows";
    case "linux": return "Linux";
    case "android": return "Android";
    case "ios": return "iOS";
    default: return "Device";
  }
}
