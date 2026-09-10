import { NextResponse } from "next/server";
import { cancelCleanJob } from "@/lib/jobs";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  let body: { jobId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body.jobId) {
    return NextResponse.json({ error: "Missing jobId" }, { status: 400 });
  }

  const cancelled = cancelCleanJob(body.jobId);
  if (!cancelled) {
    return NextResponse.json({ error: "Job not found" }, { status: 404 });
  }

  return NextResponse.json({ ok: true });
}