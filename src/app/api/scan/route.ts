import { NextResponse } from "next/server";
import { categoriesForPlatform, detectPlatform, scanCategories, platformLabel } from "@/lib/engine";
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
  const results = await scanCategories(categoriesForPlatform(platform));

  const serialized = results.map((r) => ({
    id: r.category.id,
    name: r.category.name,
    description: r.category.description,
    safety: r.category.safety,
    tradeoff: r.category.tradeoff,
    applicable: r.applicable,
    detected: r.detected,
    toolMissing: r.toolMissing ?? false,
    totalSizeBytes: r.totalSizeBytes,
    paths: r.paths.map((p) => ({ path: p.path, sizeBytes: p.sizeBytes, exists: p.exists })),
  }));

  const totalReclaimableBytes = serialized
    .filter((s) => s.detected)
    .reduce((acc, s) => acc + (Number.isFinite(s.totalSizeBytes) ? Math.max(0, s.totalSizeBytes) : 0), 0);

  return NextResponse.json({
    platform,
    platformLabel: platformLabel(platform),
    results: serialized,
    totalReclaimableBytes,
    scannedAt: Date.now(),
  });
}
