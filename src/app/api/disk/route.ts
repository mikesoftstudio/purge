import { NextResponse } from "next/server";
import { detectPlatform, getDiskInfo } from "@/lib/engine";
import { type Platform } from "@/lib/engine/types";

const VALID_PLATFORMS = new Set<Platform>(["macos", "linux", "windows", "android", "ios"]);

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const raw = searchParams.get("platform");
  const clientPlatform = raw && VALID_PLATFORMS.has(raw as Platform) ? raw as Platform : detectPlatform();
  const serverPlatform = detectPlatform();
  const isLocal = clientPlatform === serverPlatform;

  if (!isLocal) {
    return NextResponse.json({
      totalBytes: 0,
      usedBytes: 0,
      freeBytes: 0,
      home: "",
      filesystem: "",
      remote: true,
    });
  }

  const disk = await getDiskInfo();
  return NextResponse.json({ ...disk, remote: false });
}
