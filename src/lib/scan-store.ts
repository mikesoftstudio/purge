"use client";

import { ScanCategory } from "@/lib/global-types";

const KEY = "purge.last-scan";

export function saveScanResults(results: ScanCategory[], platformLabel: string, totalReclaimableBytes: number, scannedAt: number) {
  if (typeof window === "undefined") return;
  try {
    sessionStorage.setItem(
      KEY,
      JSON.stringify({ results, platformLabel, totalReclaimableBytes, scannedAt })
    );
  } catch {
    /* storage unavailable */
  }
}

export function loadScanResults(): {
  results: ScanCategory[];
  platformLabel: string;
  totalReclaimableBytes: number;
  scannedAt: number;
} | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = sessionStorage.getItem(KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

/** Map of categoryId → size in bytes from the most recent scan. */
export function sizeMapFromScan(): Record<string, number> {
  const scan = loadScanResults();
  if (!scan) return {};
  const map: Record<string, number> = {};
  for (const r of scan.results) map[r.id] = r.totalSizeBytes;
  return map;
}