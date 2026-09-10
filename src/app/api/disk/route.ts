import { NextResponse } from "next/server";
import { getDiskInfo } from "@/lib/engine";

export const dynamic = "force-dynamic";

export async function GET() {
  const disk = await getDiskInfo();
  return NextResponse.json(disk);
}