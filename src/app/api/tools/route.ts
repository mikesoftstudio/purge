import { NextResponse } from "next/server";
import { detectPlatform, detectTools, platformLabel } from "@/lib/engine";
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
      platform: clientPlatform,
      platformLabel: platformLabel(clientPlatform),
      nodeVersion: "",
      home: "",
      tools: [],
      remote: true,
    });
  }

  const tools = detectTools(clientPlatform);
  return NextResponse.json({
    platform: clientPlatform,
    platformLabel: platformLabel(clientPlatform),
    nodeVersion: process.version,
    home: process.env.HOME || process.env.USERPROFILE || "",
    tools,
    remote: false,
  });
}
