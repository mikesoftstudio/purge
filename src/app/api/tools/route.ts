import { NextResponse } from "next/server";
import { detectPlatform, detectTools, platformLabel, categoriesForPlatform, scanCategories } from "@/lib/engine";
import { type Platform } from "@/lib/engine/types";

const VALID_PLATFORMS = new Set<Platform>(["macos", "linux", "windows", "android", "ios"]);

function resolvePlatform(searchParams: URLSearchParams): Platform {
  const raw = searchParams.get("platform");
  if (raw && VALID_PLATFORMS.has(raw as Platform)) return raw as Platform;
  return detectPlatform();
}

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const platform = resolvePlatform(searchParams);
  const tools = detectTools(platform);

  return NextResponse.json({
    platform,
    platformLabel: platformLabel(platform),
    nodeVersion: process.version,
    home: process.env.HOME || process.env.USERPROFILE || "",
    tools,
  });
}
