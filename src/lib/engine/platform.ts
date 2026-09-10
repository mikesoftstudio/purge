import os from "os";
import fs from "fs";
import { Platform } from "./types";

/**
 * Detects the current platform, including mobile variants:
 * - "android" when running inside Termux on an Android device
 * - "ios" when running inside a-Shell / iSH / Blink on iOS
 * - otherwise the desktop OS.
 */
export function detectPlatform(): Platform {
  const p = os.platform();

  if (p === "darwin") return "macos";
  if (p === "win32") return "windows";

  if (p === "linux") {
    if (process.env.TERMUX_VERSION) return "android";
    if (fs.existsSync("/data/data/com.termux/files/home")) return "android";
    if (fs.existsSync("/var/mobile")) return "ios";
    return "linux";
  }

  return "linux";
}