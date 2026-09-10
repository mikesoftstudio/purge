import { NextResponse } from "next/server";
import { categoriesForPlatform, detectPlatform, scanCategories, platformLabel } from "@/lib/engine";
import { staticCategoriesForPlatform } from "@/lib/engine/static-catalog";
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
  const clientPlatform = resolvePlatform(searchParams);
  const serverPlatform = detectPlatform();
  const isLocal = clientPlatform === serverPlatform;

  if (isLocal) {
    const results = await scanCategories(categoriesForPlatform(clientPlatform));
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
      platform: clientPlatform,
      platformLabel: platformLabel(clientPlatform),
      remote: false,
      results: serialized,
      totalReclaimableBytes,
      scannedAt: Date.now(),
    });
  }

  // Remote mode: return static catalog — no filesystem access on the server.
  const staticCats = staticCategoriesForPlatform(clientPlatform);
  const results = staticCats.map((cat) => ({
    id: cat.id,
    name: cat.name,
    description: cat.description,
    safety: cat.safety,
    tradeoff: cat.tradeoff,
    applicable: true,
    detected: false,
    toolMissing: false,
    totalSizeBytes: 0,
    paths: cat.paths.map((p) => ({ path: p, sizeBytes: 0, exists: false })),
    cleanupCommands: cat.cleanupCommands,
    toolRequirement: cat.toolRequirement,
  }));

  return NextResponse.json({
    platform: clientPlatform,
    platformLabel: platformLabel(clientPlatform),
    remote: true,
    results,
    totalReclaimableBytes: 0,
    scannedAt: Date.now(),
  });
}
