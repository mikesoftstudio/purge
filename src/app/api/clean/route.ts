import { NextResponse } from "next/server";
import { getCategory } from "@/lib/engine";
import { createCleanJob } from "@/lib/jobs";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  let body: { categories?: string[]; sizes?: Record<string, number> };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const ids: string[] = Array.isArray(body.categories) ? body.categories : [];
  if (ids.length === 0) {
    return NextResponse.json({ error: "No categories selected" }, { status: 400 });
  }

  const categories = ids.map((id) => getCategory(id)).filter((c) => c !== undefined);
  if (categories.length !== ids.length) {
    return NextResponse.json(
      { error: "One or more unknown categories", unknown: ids.filter((id) => !getCategory(id)) },
      { status: 400 }
    );
  }

  // Optional pre-measured sizes from the client's last scan — avoids re-walking
  // big directories to establish the "before" size.
  let measuredSizes: Map<string, number> | undefined;
  if (body.sizes && typeof body.sizes === "object") {
    measuredSizes = new Map<string, number>();
    for (const [id, sz] of Object.entries(body.sizes)) {
      if (typeof sz === "number" && Number.isFinite(sz)) measuredSizes.set(id, Math.max(0, sz));
    }
  }

  const job = createCleanJob(categories, measuredSizes);
  return NextResponse.json({ jobId: job.id }, { status: 202 });
}