import { NextResponse } from "next/server";
import { detectPlatform, detectTools, platformLabel } from "@/lib/engine";

export const dynamic = "force-dynamic";

export async function GET() {
  const platform = detectPlatform();
  const tools = detectTools(platform);
  return NextResponse.json({
    platform,
    platformLabel: platformLabel(platform),
    nodeVersion: process.version,
    home: process.env.HOME || process.env.USERPROFILE || "",
    tools,
  });
}